require 'rails_helper'

describe RoomsController do
  describe "GET search" do
    it "renders the index template" do
      get :search
      expect(response.status).to eq(200)
    end
  end
end
