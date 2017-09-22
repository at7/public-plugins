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

package EnsEMBL::Web::Component::Tools::LD::InputForm;

use strict;
use warnings;

use parent qw(
  EnsEMBL::Web::Component::Tools::LD
  EnsEMBL::Web::Component::Tools::InputForm
);

sub form_header_info {
  ## Abstract method implementation
  my $self = shift;

  return $self->species_specific_info($self->current_species, 'LD', 'LD');
}

sub get_cacheable_form_node {
  ## Abstract method implementation
  my $self            = shift;
  my $hub             = $self->hub;
  my $object          = $self->object;
  my $sd              = $hub->species_defs;
  my $species         = $object->species_list;
  my $form            = $self->new_tool_form({'class' => 'ld-form'});
  my $fd              = $object->get_form_details;
  my $input_fieldset  = $form->add_fieldset({'no_required_notes' => 1});
  my $input_formats   = [{ 'value' => 'region', 'caption' => 'Genomic regions', 'example' => qq(1  809238  909238\n3  361464  861464) },];

  $input_fieldset->add_field({
    'label'         => 'Species',
    'elements'      => [{
      'type'          => 'speciesdropdown',
      'name'          => 'species',
      'values'        => [ map {
        'value'         => $_->{'value'},
        'caption'       => $_->{'caption'},
        'class'         => [  #selectToToggle classes for JavaScript
          '_stt', '_sttmulti',
        ]
      }, @$species ]
    }, 
    ]
  });

  $input_fieldset->add_field({
    'type'          => 'string',
    'name'          => 'name',
    'label'         => 'Name for this job (optional)'
  });

  $input_fieldset->add_field({
    'label'         => 'Either paste data',
    'elements'      => [{
      'type'          => 'text',
      'name'          => 'text',
      'class'         => 'ld-region-input',
    }, {
      'type'          => 'noedit',
      'noinput'       => 1,
      'is_html'       => 1,
      'caption'       => sprintf('<span class="small"><b>Examples:&nbsp;</b>%s</span>',
        join(', ', (map { sprintf('<a href="#" class="_example_input" rel="%s">%s</a>', $_->{'value'}, $_->{'caption'}) } @$input_formats))
      )
    },]
  });

  $input_fieldset->add_field({
    'type'          => 'file',
    'name'          => 'file',
    'label'         => 'Or upload file',
    'helptip'       => sprintf('File uploads are limited to %sMB in size. Files may be compressed using gzip or zip', $sd->ENSEMBL_TOOLS_CGI_POST_MAX->{'VEP'} / (1024 * 1024))
  });

  $input_fieldset->add_field({
    'type'          => 'dropdown',
    'name'          => 'populations',
    'label'         => 'Select one or more populations',
    'values'        => $self->get_populations(),
    'size'          => '10',
    'class'         => 'tools_listbox',
    'multiple'      => '1'
  });

  $input_fieldset->add_field({
    'type'          => 'string',
    'name'          => 'r2',
    'label'         => 'Threshold for r2'
  });

  $input_fieldset->add_field({
    'type'          => 'string',
    'name'          => 'd_prime',
    'label'         => "Threshold for D'"
  });

  # Run/Close buttons
  $self->add_buttons_fieldset($form, {'reset' => 'Clear', 'cancel' => 'Close form'});

  return $form;
}

sub get_non_cacheable_fields {
  ## Abstract method implementation
  return {};
}

sub js_panel {
  ## @override
  return 'VEPForm';
}

sub js_params {
  ## @override
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $species = $object->species_list;
  my $params  = $self->SUPER::js_params(@_);

  return $params;
}

sub get_populations {
  my $self = shift;
  return [ { value => '1000GENOMES:phase_3:GBR', caption => '1000GENOMES:phase_3:GBR' }, {value => '1000GENOMES:phase_3:GWD', caption => '1000GENOMES:phase_3:GWD'}, {value => '1000GENOMES:phase_3:CHB', caption => '1000GENOMES:phase_3:CHB'}];
}

1;
