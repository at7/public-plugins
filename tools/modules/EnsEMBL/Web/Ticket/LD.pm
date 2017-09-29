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

package EnsEMBL::Web::Ticket::LD;

use strict;
use warnings;

use List::Util qw(first);

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Job::LD;

use parent qw(EnsEMBL::Web::Ticket);

sub init_from_user_input {
  ## Abstract method implementation
  my $self      = shift;
  my $hub       = $self->hub;
  my $species   = $hub->param('species');
  my $method    = first { $hub->param($_) } qw(file url text);

  # if no data entered
  throw exception('InputError', 'No input data has been entered') unless $method;

  # build input file and data
  my $description = sprintf 'LD analysis of %s in %s', ($hub->param('name') || ($method eq 'text' ? 'pasted data' : ($method eq 'url' ? 'data from URL' : sprintf("%s", $hub->param('file'))))), $species;

  # Get file content and name
  my ($file_content, $file_name) = $self->get_input_file_content($method);

  # if no data found in file/url
  throw exception('InputError', 'No input data is present') unless $file_content;

  my @populations = $hub->param('populations');

  throw exception('InputError', 'Select at least one population') unless (scalar @populations > 0);
  my $result_headers = {};
  my @regions = ();
  if ($hub->param('ld_calculation') eq 'region') {
    foreach my $input_line (split/\n/, $file_content) {
      my ($chromosome, $start, $end) = split /\s/, $input_line;  
      throw exception('InputError', 'Input region size exceeds 100000bp') if ($start - $end + 1 > 100000);
      push @regions, "$chromosome\_$start\_$end";
    }
  }

  my $adaptor = $self->hub->get_adaptor('get_PopulationAdaptor', 'variation', $species);

  my @output_file_names = ();
  foreach my $name (@populations) {
    my $population = $adaptor->fetch_by_name($name);
    my $population_id = $population->dbID;
    foreach my $region (@regions) {
      my ($chr, $start, $end) = split/_/, $region;
      $result_headers->{"$population_id\_$region"} = "Population $name Region $chr:$start-$end";
      push @output_file_names, "$population_id\_$region";
    }
  }  

  my $job_data = { map { my @val = $hub->param($_); $_ => @val > 1 ? \@val : $val[0] } grep { $_ !~ /^text/ && $_ ne 'file' } $hub->param };
  $job_data->{'output_file_names'} = \@output_file_names;
  $job_data->{'result_headers'} = $result_headers;
  $job_data->{'species'}    = $species;
  $job_data->{'input_file'} = $file_name;

  foreach my $key (keys %$job_data) {
    print STDERR "$key $job_data->{$key}\n";
  }

  $self->add_job(EnsEMBL::Web::Job::LD->new($self, {
    'job_desc'    => $description,
    'species'     => $species,
    'assembly'    => $hub->species_defs->get_config($species, 'ASSEMBLY_VERSION'),
    'job_data'    => $job_data
  }, {
    $file_name    => {'content' => $file_content}
  }));
}

1;
