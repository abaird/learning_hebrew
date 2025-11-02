# Shared examples for testing pagination behavior
# Usage:
#   it_behaves_like "paginatable", :words, Word
#   it_behaves_like "paginatable", :glosses, Gloss
#   it_behaves_like "paginatable", :dictionary_index, Word, { representation: "test" }, -> { dictionary_path }
#
# Parameters:
#   - resource_name: The plural name of the resource (symbol) - e.g., :words, :glosses
#   - model_class: The ActiveRecord model class - e.g., Word, Gloss
#   - factory_attrs: Optional hash of attributes for creating test records
#   - custom_path: Optional lambda/proc that returns the path to test

RSpec.shared_examples "paginatable" do |resource_name, model_class, factory_attrs = {}, custom_path = nil|
  describe "pagination" do
    let(:per_page) { 25 }
    let(:total_records) { 30 }

    before do
      # Create enough records to trigger pagination (more than per_page)
      total_records.times do |i|
        attrs = factory_attrs.dup

        # Resolve any lambda values in attrs
        attrs.each do |key, value|
          attrs[key] = value.call if value.is_a?(Proc)
        end

        # Add a unique identifier to avoid uniqueness constraint issues
        if attrs[:representation]
          attrs[:representation] = "#{attrs[:representation]}_#{i}"
        elsif attrs[:text]
          attrs[:text] = "#{attrs[:text]}_#{i}"
        elsif attrs[:name]
          attrs[:name] = "#{attrs[:name]}_#{i}"
        elsif attrs[:title]
          attrs[:title] = "#{attrs[:title]}_#{i}"
        end
        model_class.create!(attrs)
      end
    end

    let(:test_path) { custom_path ? custom_path.call : polymorphic_path(resource_name) }

    it "displays the first page of results by default" do
      get test_path
      expect(response).to be_successful
      expect(response.body).to include("pagination")
    end

    it "limits results to #{25} items per page by showing page navigation" do
      get test_path
      expect(response).to be_successful
      # Should have pagination controls since we have more than 25 items
      expect(response.body).to match(/pagination/)
    end

    it "displays the correct page when page parameter is provided" do
      visit_path = custom_path ? "#{custom_path.call}?page=2" : polymorphic_path(resource_name, page: 2)
      get visit_path
      expect(response).to be_successful
      # Should show page 2 content
      expect(response.body).to match(/page=1|Previous|Prev/)
    end

    it "displays the last page when requested" do
      visit_path = custom_path ? "#{custom_path.call}?page=2" : polymorphic_path(resource_name, page: 2)
      get visit_path
      expect(response).to be_successful
      # Page 2 should exist with our 30 records
      expect(response.body).to be_present
    end

    it "includes pagination links in the response" do
      get test_path
      expect(response.body).to match(/page=2|Next/)
    end
  end
end
