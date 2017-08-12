# => RoomsController
class RoomsController < ApplicationController
  def search
    rooms_count = WgGesuchtService.new.amount_rooms
    render status: 200, json: rooms_count.to_json
  end
end
