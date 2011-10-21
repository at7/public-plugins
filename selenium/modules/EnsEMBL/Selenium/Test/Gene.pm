# $Id$
package EnsEMBL::Selenium::Test::Gene;
use strict;
use base 'EnsEMBL::Selenium::Test::Species';
use Test::More;

__PACKAGE__->set_default('timeout', 5000);
#------------------------------------------------------------------------------
# Ensembl Gene test
# Can add more cases or extend the existing test cases
#------------------------------------------------------------------------------
sub test_gene {
  my ($self) = @_;
  my $sel    = $self->sel;
  my $SD     = $self->get_species_def;

  $self->open_species_homepage($self->species, '50000');
  my $gene_text  = $SD->get_config(ucfirst($self->species), 'SAMPLE_DATA')->{'GENE_TEXT'};
  my $gene_param = $SD->get_config(ucfirst($self->species), 'SAMPLE_DATA')->{'GENE_PARAM'};
  my $species_db = $self->species_databases($SD);

  if($gene_text) {
    $sel->ensembl_click_links(["link=Gene ($gene_text)"],"50000")
    and $sel->ensembl_is_text_present("Gene: $gene_text ($gene_param)");

    if(lc($self->species) eq 'homo_sapiens') {
      print "  Test ZMenu on Gene Summary\n";
      $sel->ensembl_open_zmenu('TranscriptsImage','class^="drag"');
      $sel->ensembl_click("link=Jump to location View")      
      and $sel->ensembl_wait_for_ajax_ok('50000','2000')
      and $sel->go_back();

      $sel->ensembl_wait_for_page_to_load;

      #Adding a track from the configuration panel
      print "  Test Configure page, adding a track \n";
      $sel->ensembl_click("link=Configure this page")
      and $sel->ensembl_wait_for_ajax_ok('10000','3000')
      and $sel->ensembl_click("link=Somatic mutations")
      and $sel->ensembl_wait_for_ajax_ok('10000','3000')
      and $sel->click_ok("//form[\@id='gene_transcriptsimage_configuration']/div[4]/div/ul/li[2]/img") #selecting the second track
      and $sel->ensembl_is_text_present("Somatic mutations(1/*")
      and $sel->ensembl_click("modal_bg")
      and $sel->ensembl_wait_for_ajax_ok('15000','2000')
      and $sel->ensembl_images_loaded;
    }

    $sel->ensembl_click_links([
      "link=Splice variants*",
      "link=Supporting evidence",
      "link=Sequence",
      "link=External references*",
      "link=Comparative Genomics"
     ],'20000');
    $sel->ensembl_click_links(["link=Regulation"]) if($SD->table_info_other(ucfirst($self->species),'funcgen', 'feature_set')->{'rows'} && $gene_text !~ /^ASMPATCH/);

    if(lc($self->species) eq 'homo_sapiens') {
      print "  Test ZMenu on Regulation\n";
      $sel->ensembl_open_zmenu('RegulationImage','class^="group"');
      $sel->ensembl_click("link=ENSR*")
      and $sel->ensembl_wait_for_ajax_ok('50000','2000')
      and $sel->go_back();
    }

    my ($alignment_count,$multi_species_count) = $self->alignments_count($SD);
    $sel->ensembl_click_links(["link=Genomic alignments"],'20000') if($alignment_count);
    #"link=Gene Tree (image)", need to add back to array below
    $sel->ensembl_click_links([
      "link=Gene Tree (text)",
      "link=Gene Tree (alignment)"
    ],'20000') if(lc($self->species) ne 'saccharomyces_cerevisiae');

    my $counts = $self->count_homologues($gene_param);
    $sel->ensembl_click_links(["link=Orthologues ($counts->{'orthologs'})"],'20000') if($counts->{'orthologs'});
    $sel->ensembl_click_links(["link=Paralogues ($counts->{'paralogs'})"],'20000') if($counts->{'paralogs'});
    $sel->ensembl_click_links(["link=Protein families*"],'20000') if($counts->{'families'});
    
    $sel->ensembl_click("link=JalView")
    and $sel->ensembl_wait_for_page_to_load
    and $sel->go_back() if(lc($self->species) eq 'homo_sapiens'); #testing for human only as this is opening too many java applet and making the server slow

    $sel->pause(1000);
    $sel->ensembl_click_links(["link=all proteins in family"],'20000') if($counts->{'families'});
    
    $sel->ensembl_click_links(["link=Phenotype"]);
    
    if(lc($self->species) eq 'homo_sapiens') {
      $sel->ensembl_click("link=view all locations")
      and $sel->ensembl_wait_for_page_to_load
      and $sel->go_back();     
    
      $sel->ensembl_click("link=[View on Karyotype]")
      and $sel->ensembl_wait_for_page_to_load
      and $sel->go_back();
    }

    $sel->ensembl_click_links(["link=Variation Table", "link=Variation Image", "link=Structural Variation"]) if($species_db->{'database:variation'} && $gene_text !~ /^ASMPATCH/);

    print "  Test Configure page on External Data \n";
    $sel->ensembl_click("link=External Data",'20000')
    and $sel->ensembl_wait_for_page_to_load
    and $sel->ensembl_click("link=Configure this page")
    and $sel->ensembl_wait_for_ajax_ok(10000,2000)
    and $sel->ensembl_click("//div[\@class='ele-das']//input[\@type='checkbox'][1]") # tick first source
    and $sel->ensembl_click("modal_bg")
    and $sel->ensembl_wait_for_ajax_ok(10000,5000);

    my $url  = $self->get_location();
    print "DAS ERROR at $url (click on configure page and choose the first das source) \n"  if ($sel->ensembl_has_das_error);

    $sel->ensembl_click_links(["link=Gene history"]) if($SD->table_info_other(ucfirst($self->species),'core', 'stable_id_event')->{'rows'});

    $self->export_data('FASTA sequence','cdna:') if(lc($self->species) eq 'homo_sapiens');
    
  } else {
    print "  No Gene \n";
  }
}

1;