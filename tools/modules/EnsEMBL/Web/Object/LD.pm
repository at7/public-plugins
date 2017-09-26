=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Object::LD;

use strict;
use warnings;

use HTML::Entities  qw(encode_entities);

use EnsEMBL::Web::TmpFile::ToolsOutput;
use EnsEMBL::Web::TmpFile::VcfTabix;
use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);
use Bio::EnsEMBL::Variation::Utils::Constants;
use Bio::EnsEMBL::Variation::Utils::VariationEffect;

use parent qw(EnsEMBL::Web::Object::Tools);

sub tab_caption {
  ## @override
  return 'LD';
}

sub valid_species {
  ## @override
  my $self = shift;
  return $self->hub->species_defs->reference_species($self->SUPER::valid_species(@_));
}

sub get_edit_jobs_data {
  ## Abstract method implementation
  my $self        = shift;
  my $hub         = $self->hub;
  my $ticket      = $self->get_requested_ticket   or return [];
  my $job         = shift @{ $ticket->job || [] } or return [];
  my $job_data    = $job->job_data->raw;
  my $input_file  = sprintf '%s/%s', $job->job_dir, $job_data->{'input_file'};

  if (-T $input_file && $input_file !~ /\.gz$/ && $input_file !~ /\.zip$/) { # TODO - check if the file is binary!
    if (-s $input_file <= 1024) {
      $job_data->{"text"} = file_get_contents($input_file);
    } else {
      $job_data->{'input_file_type'}  = 'text';
      $job_data->{'input_file_url'}   = $self->download_url({'input' => 1});
    }
  } else {
    $job_data->{'input_file_type'} = 'binary';
  }

  return [ $job_data ];
}

sub result_files {
  ## Gets the result stats and ouput files
  my $self = shift;

  if (!$self->{'_results_files'}) {
    my $ticket      = $self->get_requested_ticket or return;
    my $job         = $ticket->job->[0] or return;
    my $job_config  = $job->dispatcher_data->{'config'};
    my $job_dir     = $job->job_dir;

    $self->{'_results_files'} = {
      'output_file' => EnsEMBL::Web::TmpFile::ToolsOutput->new('filename' => "$job_dir/$job_config->{'output_file'}"),
    };
  }

  return $self->{'_results_files'};
}

sub handle_download {
  my ($self, $r) = @_;

  my $hub = $self->hub;
  my $job = $self->get_requested_job;

  # if downloading the input file
  if ($hub->param('input')) {

    my $filename  = $job->job_data->{'input_file'};
    my $content   = file_get_contents(join('/', $job->job_dir, $filename), sub { s/\R/\r\n/r });

    $r->headers_out->add('Content-Type'         => 'text/plain');
    $r->headers_out->add('Content-Length'       => length $content);
    $r->headers_out->add('Content-Disposition'  => sprintf 'attachment; filename=%s', $filename);

    print $content;

  # if downloading the result file in any specified format
  } else {

    my $format    = $hub->param('format')   || 'vcf';
    my $location  = $hub->param('location') || '';
    my $filter    = $hub->param('filter')   || '';
    my $file      = $self->result_files->{'output_file'};
    my $filename  = join('.', $job->ticket->ticket_name, $location || (), $filter || (), $format eq 'txt' ? () : $format, $format eq 'vcf' ? '' : 'txt') =~ s/\s+/\_/gr;

    $r->headers_out->add('Content-Type'         => 'text/plain');
    $r->headers_out->add('Content-Disposition'  => sprintf 'attachment; filename=%s', $filename);

    $file->content_iterate({'format' => $format, 'location' => $location, 'filter' => $filter}, sub {
      print "$_\r\n" for @_;
      $r->rflush;
    });
  }
}

sub get_form_details {
  my $self = shift;
  if(!exists($self->{_form_details})) {
    # core form
    


    $self->{_form_details} = {
      ld_calculation => {
        'label' => 'Choose calculation',
        'helptip' => 
          '<b>Compute pairwise LD values in a region, compute all pairwise LD values for list of variants, or</b>'.
          '<b>compute all LD values for a given variant and all variants that are not further away from the</b>'.
          '<b>given variant than a given window size.</b>',
        'values' => [
          { 'value' => 'region', 'caption' => 'Pairwise LD in a given region' },
          { 'value' => 'pairwise', 'caption' => 'Pairwise LD for a given list of variants' },
          { 'value' => 'variant', 'caption' => 'LD for a given variant within a defined region' },
        ],
      },
      r2_threshold => {
        'label' => 'r2',
        'helptip' => 'Only include variants whose r2 value is greater than the given value'
      },
      d_prime_threshold => {
        'label' => 'd_prime',
        'helptip' => 'Only include variants whose d_prime value is greater than the given value'
      },
      window_size => {
        'label' => 'window size',
        'helptip' => 'Only compute LD between the input variant and all variants that are not further away from the input variant than the given window size',
      },
    };
  }
  return $self->{_form_details};
}

sub populations_with_LD {
  my $self = shift;
  my $hub = $self->hub;
  my $sd = $hub->species_defs;
  for ($self->valid_species) {
    my $db_config = $sd->get_config($_, 'databases');
    if ($db_config->{'DATABASE_VARIATION'}) {
      if (! defined $self->{'_population_list'}->{$_}) {
        my $adaptor = $self->hub->get_adaptor('get_PopulationAdaptor', 'variation', $_);
        my $ld_populations = $adaptor->fetch_all_LD_Populations;
        foreach my $ld_population (@$ld_populations) {
          my $name = $ld_population->name;
          push @{$self->{'_population_list'}->{$_}}, {'value' => $name, 'caption' => $name};
        }
      }
    }
  }
  return $self->{'_population_list'};
}

sub species_list {
  ## Returns a list of species with VEP specific info
  ## @return Arrayref of hashes with each hash having species specific info
  my $self = shift;

  if (!$self->{'_species_list'}) {
    my $hub     = $self->hub;
    my $sd      = $hub->species_defs;
    my @species;

    for ($self->valid_species) {

      my $db_config = $sd->get_config($_, 'databases');

      if ($db_config->{'DATABASE_VARIATION'}) {
        # if has enough sample genotype data for LD computation
        push @species, {
          'value'       => $_,
          'caption'     => $sd->species_label($_, 1),
          'assembly'    => $sd->get_config($_, 'ASSEMBLY_NAME') // undef,
        };
      }
    }
    @species = sort { $a->{'caption'} cmp $b->{'caption'} } @species;

    $self->{'_species_list'} = \@species;
  }
  return $self->{'_species_list'};
}

1;
