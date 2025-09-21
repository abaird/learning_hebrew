require "rails_helper"

RSpec.describe GlossesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/glosses").to route_to("glosses#index")
    end

    it "routes to #new" do
      expect(get: "/glosses/new").to route_to("glosses#new")
    end

    it "routes to #show" do
      expect(get: "/glosses/1").to route_to("glosses#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/glosses/1/edit").to route_to("glosses#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/glosses").to route_to("glosses#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/glosses/1").to route_to("glosses#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/glosses/1").to route_to("glosses#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/glosses/1").to route_to("glosses#destroy", id: "1")
    end
  end
end
