=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Tools::FileChameleon::InputForm;

use strict;
use warnings;

use EnsEMBL::Web::FileChameleonConstants qw(INPUT_FORMATS STYLE_FORMATS CONVERSION_FORMATS);

use parent qw(
  EnsEMBL::Web::Component::Tools::FileChameleon
  EnsEMBL::Web::Component::Tools::InputForm
);

sub form_header_info {
  ## Abstract method implementation
  return '<p class="info">To use Ensembl data for your genomic analysis, download files customised for your tool with File Chameleon. If you would like us to support additional customisations please contact us at <a href="mailto:helpdesk@ensembl.org?Subject=File Chameleon feedback" target="_top">helpdesk@ensembl.org</a></p><p><b>Important Note:</b> File Chameleon does not convert between file formats.</p>';
}

sub get_cacheable_form_node {
  ## Abstract method implementation
  my $self            = shift;
  my $species         = $self->object->species_list;
  my $form            = $self->new_tool_form;
  my $input_formats   = INPUT_FORMATS;
  my $style_formats   = STYLE_FORMATS;
  my $conversion      = CONVERSION_FORMATS
  my $input_fieldset  = $form->add_fieldset();
  my $url             = $self->hub->url({'function' => ''});
  my $release         = $self->hub->species_defs->ENSEMBL_VERSION;

  $input_fieldset->add_field({
    'type'          => 'string',
    'name'          => 'name',
    'label'         => 'Name for this job (optional)'
  });
  
  # Species dropdown list with stt classes to dynamically toggle other fields
  $input_fieldset->add_field({
    'label'         => 'Species',
    'elements'      => [{
      'type'          => 'speciesdropdown',
      'name'          => 'species',
      'values'        => [ map {
        'value'         => $_->{'value'},
        'caption'       => $_->{'caption'},
        'class'         => [
          '_stt', '_sttmulti',
          $_->{'chr_filter'}  ? '_stt__chr_filter'   : (),
        ]
      }, @$species ]
    }, {
      'type'          => 'noedit',
      'value'         => 'Assembly: '. join('', map { sprintf '<span class="_stt_%s" rel="%s">%s</span>', $_->{'value'}, $_->{'assembly'}, $_->{'assembly'} } @$species),
      'no_input'      => 1,
      'is_html'       => 1
    }]
  });
  
  
  my $format_fieldset  = $form->add_fieldset();
  $format_fieldset->add_field({
    'type'          => 'radiolist',
    'name'          => 'format',
    'label'         => 'File format',
    'values'        => $input_formats,
    'class'         => 'format _stt'
  });
  
  $format_fieldset->add_field({
    'label'         => 'File',
    'elements'      => [{
      'type'          => 'noedit',      
      'value'         => qq{<select class="fselect hidden" style="width: auto" name="files_list"><option value='null'></option></select><span class="_file_text"></span><span class="file_link hidden left-margin small"><a href=$url>Select a different file</a></span>},
      'no_input'      => 1,
      'is_html'       => 1,      
    }]    
  });
  
  $format_fieldset->add_field({
    'type'          => 'string',
    'name'          => 'release',
    'value'         => $release,
    'field_class'   => 'hidden'
  });  
  
  $self->togglable_fieldsets($form, {
    'title' => "File Listing",
    'desc'  => "list the file formats and the files",
    'open'  => 1,
  }, $format_fieldset);
  
  my $filter_fieldset  = $form->add_fieldset();
  $filter_fieldset->add_field({
    'type'          => 'dropdown',
    'name'          => 'chr_filter',
    'label'         => '<span class="ht _ht"><span class="_ht_tip hidden">Select between Ensembl and UCSC naming styles</span>Change chromosome naming style</span>',
    'values'        => $style_formats, 
    'field_class'   => '_stt_fasta _stt_gtf _stt_gff3 _stt_chr_filter hidden _filters',    
  });

  $filter_fieldset->add_field({
    'type'          => 'dropdown',
    'name'          => 'long_genes',
    'label'         => '<span class="ht _ht"><span class="_ht_tip hidden">Remove genes longer than the value selected</span>Remove long genes</span>',
    'values'        => [{ 'value' => 'null',   'caption' => '',  'example' => qq() },{ 'value' => '2000000',   'caption' => '2Mbp',  'example' => qq() },{ 'value' => '4000000',   'caption' => '4Mbp',  'example' => qq() }, {'value' => '6000000',   'caption' => '6Mbp',  'example' => qq() },{ 'value' => '8000000',   'caption' => '8Mbp',  'example' => qq() }],
    'field_class'   => '_stt_gtf _stt_gff3 hidden _filters',    
  });

  $filter_fieldset->add_field({
    'type'          => 'checklist',
    'name'          => 'add_transcript',
    'label'         => '<span class="ht _ht"><span class="_ht_tip hidden">Add transcript IDs to each line</span>Add transcript IDs</span>',
    'values'        => [ { 'value' => '1' } ],
    'field_class'   => '_stt_gtf _stt_gff3 hidden _filters',
  });

  $filter_fieldset->add_field({
    'type'          => 'checklist',
    'name'          => 'remap_patch',
    'label'         => '<span class="ht _ht"><span class="_ht_tip hidden">Convert gene or transcript coordinates from the reference to the stand-alone patch</span>Remap patches</span>',
    'values'        => [ { 'value' => '1' } ],
    'field_class'   => '_remap hidden _filters',
  });

  $self->togglable_fieldsets($form, {
    'title' => "Custom Options",
    'desc'  => "list the options to customise files",
    'open'  => 1
  }, $filter_fieldset);    
  
  $filter_fieldset->prepend_child("p", {"inner_HTML" => "No filters are available for your selections; you can only download the file by clicking Run below.", 'class' => 'nofilter_note hidden bold'});
  $filter_fieldset->prepend_child("p", {"inner_HTML" => "<b>Note:</b> Do not choose any of the options below if you want to just download the unedited file.",});
  $self->add_buttons_fieldset($form, {'reset' => 'Clear', 'cancel' => 'Close form'});

  return $form;
}

sub get_non_cacheable_fields {
  ## Abstract method implementation
  return { };
}

sub js_panel {
  ## @override
  return 'FileChameleonForm';
}

1;
