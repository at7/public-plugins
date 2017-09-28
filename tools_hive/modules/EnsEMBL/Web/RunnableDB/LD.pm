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

package EnsEMBL::Web::RunnableDB::LD;

### Hive Process RunnableDB for LD

use strict;
use warnings;

use parent qw(EnsEMBL::Web::RunnableDB);

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::SystemCommand;
use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);
use EnsEMBL::Web::Utils::FileSystem qw(list_dir_contents);
use Bio::EnsEMBL::Registry;
use FileHandle;
use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

sub fetch_input {
  my $self = shift;

  # required params
#  $self->param_required($_) for qw(work_dir config job_id);
}

sub run {
  my $self = shift;

  # method: region, pairwise, center
  # populations
  # thresholds r2 d_prime
  my $working_dir = $self->param('working_dir');
  my $output_file = $self->param('output_file');
  my $input_file = $self->param('input_file');
  my $ld_binary = $self->param('ld_binary');
  my $ld_tmp_space  = $self->param('ld_tmp_space');
  my $config = $self->param('config');

  my $vcf_config = $self->param('vcf_config');
  my $data_file_base_path = $self->param('data_file_base_path');
  my $vcf_tmp_dir = $self->param('vcf_tmp_dir');

  my $analysis = $config->{'ld_calculation'};
  my @populations = ();
  if (ref($config->{'populations'}) eq "ARRAY") {
    @populations = @{$config->{'populations'}};
  } else {
    @populations = ($config->{'populations'});
  }
  my $d_prime = $config->{'d_prime'};
  my $r2 = $config->{'r2'};

  my $dbc_params = $self->param('core');
  my $core_dbname = $dbc_params->{'dbname'};
  my $core_host = $dbc_params->{'host'};
  my $core_user = $dbc_params->{'user'};
  $self->warning("$core_dbname $core_user $core_host");

  my $dbv_params = $self->param('variation');
  my $variation_dbname = $dbv_params->{'dbname'};
  my $variation_host = $dbv_params->{'host'};
  my $variation_user = $dbv_params->{'user'};
  $self->warning("$variation_dbname $variation_user $variation_host");

  my $registry = 'Bio::EnsEMBL::Registry';
  $registry->load_registry_from_db(
    -host => 'ensembldb.ensembl.org',
    -user => 'anonymous',
  );

  my $species = 'homo_sapiens';

  my $vdba = $registry->get_DBAdaptor($species, 'variation');

  $vdba->vcf_config_file($vcf_config);
  $vdba->vcf_root_dir($data_file_base_path);
  $vdba->vcf_tmp_dir($vcf_tmp_dir);
  $vdba->use_vcf(1);

  my $cdba = $registry->get_DBAdaptor($species, 'core');

  my $population_adaptor = $vdba->get_PopulationAdaptor;
  my $variation_adaptor = $vdba->get_VariationAdaptor;
  my $slice_adaptor = $cdba->get_SliceAdaptor;

  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::VCF_BINARY_FILE = $ld_binary;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH        = $ld_tmp_space;

  my $ld_feature_container_adaptor = $vdba->get_LDFeatureContainerAdaptor;

  if ($analysis eq 'region') {
    my @regions = @{$self->parse_regions("$working_dir/$input_file")};
    foreach my $region (@regions) {
      my ($chromosome, $start, $end) = split /\s/, $region;
      my $slice = $slice_adaptor->fetch_by_region('chromosome', $chromosome, $start, $end);
      foreach my $population_name (@populations) {
        my $population = $population_adaptor->fetch_by_name($population_name);
        my $population_id = $population->dbID;
        my $bin = $ld_feature_container_adaptor->vcf_executable;
        $self->warning("vcf_executable $bin");
        $self->warning("Call ld_feature_container_adaptor with $slice $population");        
        my $ld_feature_container = $ld_feature_container_adaptor->fetch_by_Slice($slice, $population);
        $self->warning("Print ld_feature_container");        
        $self->ld_feature_container_2_file($ld_feature_container, "$working_dir/$population_id\_$chromosome\_$start\_$end");
      }
    }
  }
  return 1;
}

sub write_output {
  my $self        = shift;
  my $job_id      = $self->param('job_id');
  return 1;
}

sub parse_regions {
  my $self = shift;
  my $file = shift;
  my @regions = ();
  my $fh = FileHandle->new($file, 'r');
  while (<$fh>) {
    chomp;
    push @regions, $_;
  }
  $fh->close;
  return \@regions;
}

sub ld_feature_container_2_file {
  my $self = shift;
  my $container = shift;
  my $output_file = shift;
  my $config = $self->param('config');
  my $d_prime_threshold = $config->{'d_prime'};
  my $r2_threshold = $config->{'r2'};
  my $no_vf_attribs = 1;
  $self->warning("print ld feature container to $output_file");
  my $fh = FileHandle->new($output_file, 'w');
  my $count = scalar @{$container->get_all_ld_values($no_vf_attribs)};
  $self->warning("write $count pairs");
  foreach my $ld_hash (@{$container->get_all_ld_values($no_vf_attribs)}) {
    my $d_prime = $ld_hash->{d_prime};
    my $r2 = $ld_hash->{r2};
    next unless ($d_prime >= $d_prime_threshold && $r2 >= $r2_threshold);
    my $variation1 = $ld_hash->{variation_name1};
    my $variation2 = $ld_hash->{variation_name2};
#    my $variation1_start = $ld_hash->{variation_start1};
#    my $variation2_start = $ld_hash->{variation_start2};
    print $fh join("\t", $variation1, $variation2, $r2, $d_prime), "\n";
  }
  $fh->close;
}

1;
