Given /^a supplier called "(.*)" exists$/ do |supplier_name|
  Supplier.create!({:name => supplier_name })
end

Given /^the study "(.*)" has a abbreviation$/ do |study_name|
  study = Study.find_by_name(study_name)
  study.study_metadata.study_name_abbreviation = "TEST"
end

Given /^sample information is updated from the manifest for study "([^"]*)"$/ do |study_name|
  study = Study.find_by_name(study_name) or raise StandardError, "Cannot find study #{study_name.inspect}"
  study.samples.each_with_index do |sample,index|
    sample.update_attributes_from_manifest!(
      :name => "#{study.abbreviation}#{index+1}",
      :sanger_sample_id => sample.name,
      :sample_metadata_attributes => {
        :gender           => "Female",
        :dna_source       => "Blood",
        :sample_sra_hold  => "Hold"
      }
    )
  end
end

Then /^study "([^"]*)" should have (\d+) samples$/ do |study_name, number_of_samples|
  study = Study.find_by_name(study_name)
  assert_equal number_of_samples.to_i, study.samples.size
end

Then /^I should see the manifest table:$/ do |expected_results_table|
  expected_results_table.diff!(table(tableish('table#study_list tr', 'td,th')))
end

Given /^I reset all of the sanger sample ids to a known number sequence$/ do
  Sample.all.each_with_index do |sample,index|
    sample.sanger_sample_id = "sample_#{index}"
    sample.save
  end
end

Then /^sample "([^"]*)" should have empty supplier name set to "([^"]*)"$/ do |sanger_sample_id, boolean_string|
  sample = Sample.find_by_sanger_sample_id(sanger_sample_id)
  if boolean_string == "true"
    assert sample.empty_supplier_sample_name
  else
    assert ! sample.empty_supplier_sample_name
  end
end

# This resets the auto-increment column of the SangerSampleId table so that their IDs start back a 1.
# NOTE: Use sparringly because you shouldn't be relying on the ID values anyway.
Given /^the Sanger sample IDs have been reset$/ do
  SangerSampleId.connection.execute("ALTER TABLE #{SangerSampleId.quoted_table_name} AUTO_INCREMENT=1")
end

Then /^the samples table should look like:$/ do |table|
  table.hashes.each do |expected_data|
    sample = Sample.find_by_sanger_sample_id(expected_data[:sanger_sample_id])
    assert_not_nil sample
    if expected_data[:empty_supplier_sample_name] == "true"
      assert sample.empty_supplier_sample_name
    else
      assert ! sample.empty_supplier_sample_name
      assert_equal  expected_data[:supplier_name], sample.sample_metadata.supplier_name
    end
    if sample.sample_metadata.sample_taxon_id.blank?
      assert_nil sample.sample_metadata.sample_taxon_id
    else
      assert_equal expected_data[:sample_taxon_id].to_i, sample.sample_metadata.sample_taxon_id
    end
    
    unless expected_data[:common_name].blank?
      assert_equal expected_data[:common_name], sample.sample_metadata.sample_common_name
    end
  end
end

Given /^a manifest has been created for "([^"]*)"$/ do |study_name|
  When %Q{I follow "Create manifest for plates"}
	Then %Q{I should see "Barcode printer"}
	When %Q{I select "#{study_name}" from "Study"}
	And %Q{I select "Test supplier name" from "Supplier"}
	And %Q{I select "xyz" from "Barcode printer"}
	And %Q{I fill in the field labeled "Count" with "1"}
	When %Q{I press "Create manifest and print labels"}
	Then %Q{I should see "Manifest_"}
	Then %Q{I should see "Download Blank Manifest"}
	Given %Q{3 pending delayed jobs are processed}
	When %Q{I follow "View all manifests"}
	Then %Q{I should see "Sample Manifests"}
	Then %Q{I should see "Upload a sample manifest"}
	And %Q{study "#{study_name}" should have 96 samples}
	Given %Q{I reset all of the sanger sample ids to a known number sequence}
end

Then /^the sample controls and resubmits should look like:$/ do |table|
  found = table.hashes.map do |expected_data|
    sample = Sample.find_by_sanger_sample_id(expected_data[:sanger_sample_id]) or raise StandardError, "Cannot find sample by sanger ID #{expected_data[:sanger_sample_id]}"
    {
      'sanger_sample_id' => expected_data[:sanger_sample_id],
      'supplier_name'             => sample.sample_metadata.supplier_name,
      'is_control'       => sample.control.to_s,
      'is_resubmit'      => sample.sample_metadata.is_resubmitted.to_s
    }
  end
  assert_equal(table.hashes, found)
end

When /^I visit the sample manifest new page without an asset type$/ do
  visit('/sdb/sample_manifests/new')
end

Given /^plate "([^"]*)" has samples with known sanger_sample_ids$/ do |plate_barcode|
  Plate.find_by_barcode(plate_barcode).wells.each_with_index do |well,i|
    well.sample.update_attributes!(:sanger_sample_id => "ABC_#{i}")
  end
end

Then /^the last created sample manifest should be:$/ do |table|
  offset = 9
  Tempfile.open('testfile.xls') do |tempfile|
    tempfile.write(SampleManifest.last.generated.data)
    tempfile.flush
    tempfile.open

    spreadsheet = Spreadsheet.open(tempfile.path)
    @worksheet   =spreadsheet.worksheets.first
  end
  
  table.rows.each_with_index do |row,index|
    assert_equal @worksheet[offset+index,0], Barcode.barcode_to_human(Barcode.calculate_barcode(Plate.prefix, row[0].to_i))
    assert_equal @worksheet[offset+index,1], row[1]
  end
end

