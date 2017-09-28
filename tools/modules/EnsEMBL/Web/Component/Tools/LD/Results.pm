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

package EnsEMBL::Web::Component::Tools::LD::Results;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Component::Tools::LD);

use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);

sub buttons {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $job     = $object->get_requested_job({'with_all_results' => 1});

  return unless $job && $job->status eq 'done' && @{$job->result};

  return {
    'class'     => 'export',
    'caption'   => 'Download results file',
    'url'       => $object->download_url
  };
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $sd      = $hub->species_defs;
  my $object  = $self->object;
  my $ticket  = $object->get_requested_ticket;
  my $job     = $ticket ? $ticket->job->[0] : undef;

  return '' if !$job || $job->status ne 'done';

  my $job_data  = $job->job_data;

  my $job_config  = $job->dispatcher_data->{'config'};
  my @output_file_names = @{$job_config->{'output_file_names'}};

  my $species   = $job->species;
  my @warnings  = grep { $_->data && ($_->data->{'type'} || '') eq 'LDWarning' } @{$job->job_message};

  # this method reconstitutes the Tmpfile objects from the filenames
  my $output_file = $output_file_names[0];  
  my $output_file_obj = $object->result_files->{$output_file};

  my $html = 'work in progress';
  my $ticket_name = $object->parse_url_param->{'ticket_name'};

#  my ($header_hash, $rows, $line_count) = @{$output_file_obj->content_parsed(\%content_args)};
  my @content = file_get_contents(join('/', $job->job_dir, $output_file), sub { s/\R/\r\n/r });

#  print STDERR "Content $content\n";
  my %header_titles = (
    'VARIANT1' => 'Variant 1',
    'VARIANT2' => 'Variant 2',
    'R2'       => 'r2',
    'D_PRIME' => "D'",
  );
  my %table_sorts = (
    'R2'      => 'numeric',
    'D_PRIME' => 'numeric',
  );

  my @rows;
  my @headers = qw/VARIANT1 VARIANT2 R2 D_PRIME/;

  my $preview_count = 10;
  foreach my $line (@content) {
    chomp $line;
    my @split     = split /\s+/, $line;
    my %raw_data  = map { $headers[$_] => $split[$_] } 0..$#headers;
    if ($preview_count) {
      push @rows, \%raw_data;
      $preview_count--;
    } else {
      last;
    }
  }

  my @table_headers = map {{
    'key' => $_,
    'title' => ($header_titles{$_} || $_).'<sup style="color:grey">(p)</sup>',
    'sort' => $table_sorts{$_} || 'string',
    'help' => 'help',
#    'help' => $FIELD_DESCRIPTIONS{$_} || $header_extra_descriptions->{$_},
  }} @headers;

# render table
  my $table = $self->new_table(\@table_headers, \@rows, { data_table => 1, sorting => [ 'R2 asc' ], exportable => 0, data_table_config => {bLengthChange => 'false', bFilter => 'false'}, });
  $html .= $table->render || '<h3>No data</h3>';

  my $down_url  = $object->download_url({output_file => $output_file});

  $html .= qq{<p>Click on the button below to download the result file.</p><p><div class="component-tools tool_buttons"><a class="export" href="$down_url">Download results file</a></div></p>};

  return $html;
}


1;
