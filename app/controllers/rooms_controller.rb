class RoomsController < ApplicationController
  def search
    rooms = WgGesuchtService.new
    render status: 200, json: {}
  end
end
