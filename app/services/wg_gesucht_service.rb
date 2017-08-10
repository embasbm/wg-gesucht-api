require 'mechanize'

class WgGesuchtService
  def initialize
    @a = Mechanize.new
    @my_page = start_session
    find_rooms
  end

  def start_session

    @a.get('https://www.wg-gesucht.de/') do |page|
      login_page = @a.click(page.link_with(:text => /Login/))

      f = login_page.forms.select { |x| x.fields.map(&:name).include?('login_email_username') }.first
      f.login_email_username = ENV['login']
      f.login_password = ENV['password']
      f.click_button
    end
  end

  def find_rooms
    city_form_page = @a.get('https://www.wg-gesucht.de/wg-zimmer-in-Hamburg-gesucht.55.0.1.0.html')
    search_form_page = city_form_page.form_with(name: 'request_filter_form') do |f|
      f.dFr = '1508450400'
      f.dTo = '1509490800'
      f.aMin = '33'
      f.aMax = '33'
    end.submit
    # TODO: search_form_page got the result, need to parse it and get the data from the links!
  end
end
