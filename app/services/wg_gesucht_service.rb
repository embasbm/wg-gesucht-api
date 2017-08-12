require 'mechanize'
require 'csv'
# => WgGesuchtService
class WgGesuchtService
  def initialize
    @base_url = 'https://www.wg-gesucht.de/'
    @a = Mechanize.new
    @my_page = start_session
    @interesting_rooms = []
    @skipped_rooms = []
    find_rooms
    write_interesting_rooms_to_files
  end

  def amount_rooms
    @interesting_rooms.count
  end

  def start_session
    @a.get(@base_url) do |page|
      login_page = @a.click(page.link_with(text: /Login/))

      f = login_page.forms.select do |x|
        x.fields.map(&:name).include?('login_email_username')
      end.first
      f.login_email_username = ENV['login']
      f.login_password = ENV['password']
      f.click_button
    end
  end

  def find_rooms
    city_form_page = @a.get("#{@base_url}wg-zimmer-in-Hamburg.55.0.1.0.html")
    pages_amount = city_form_page.links.select { |x| x.text.squish.match(/^[0-9]+$/) }.try(:last).try(:text).try(:squish).to_i
    0.upto(pages_amount) do |page|
      city_form_page = @a.get("#{@base_url}wg-zimmer-in-Hamburg.55.0.1.#{page}.html")
      search_form_page = city_form_page.form_with(name: 'offer_filter_form') do |f|
        fill_form(f)
      end.submit
      fetch_data(search_form_page)
    end
  end

  def fill_form(f)
    my_age = 33
    f.dFr = Date.parse('20/10/2017').strftime('%s')
    f.dTo = Date.parse('01/11/2017').strftime('%s')
    f.wgAge = my_age.to_s
  end

  def fetch_data(page)
    hrefs_to_ads = page.links.select do |x|
      x.href && x.href.match(/wg-zimmer-in-Hamburg.*\d{7}\.html/)
    end.group_by(&:href)
    hrefs_to_ads.keys.each do |link|
      adv_link = hrefs_to_ads[link].first
      adv_page = adv_link.click
      next if something_is_worng(adv_link, adv_page)
      populate_data_set(adv_link, adv_page)
    end
  end

  def populate_data_set(adv_link, page)
    data_hash = Hash.new(0)
    title = adv_link.text.squish
    href = adv_link.href
    data_hash[:title] = title
    data_hash[:href] = @base_url + href
    data_hash[:name] =
      page.search('.rhs_contact_information .text-capitalise').text.squish
    data_hash[:phone_number] =
      page.search('.rhs_contact_information .vis').empty? ? 'No' : 'Yes' || ''
    # TODO: if no phone number, send email
    data_hash[:size] =
      page.search('h2.headline-key-facts').first.text.squish.delete('m²').to_i || ''
    data_hash[:cost] =
      page.search('h2.headline-key-facts').last.text.squish.delete('€').to_i || ''
    table = page.search('.col-xs-12.col-sm-5 table tr')[3] || ''
    data_hash[:caution] =
      table.search('td').last.text.squish.delete('€').to_i || ''
    data_hash[:address] =
      page.search('.col-xs-12.col-sm-4')[0].text.squish.gsub('Umzugsfirma beauftragen1', '').squish || ''
    data_hash[:date_from] = page.search('.col-xs-12.col-sm-3').text.squish.split[3] || ''
    data_hash[:date_to] = page.search('.col-xs-12.col-sm-3').text.squish.split[6] || ''
    data_hash[:looking_for] = page.search('.ul-detailed-view-datasheet.print_text_left').last.text.squish || ''
    data_hash[:description] = page.search('.panelToTranslate').text.squish || ''
    @interesting_rooms << data_hash
  end

  def something_is_worng(adv_link, page)
    table = page.search('.col-xs-12.col-sm-5 table tr')[3] || ''
    date_to =
      begin
        Date.parse(page.search('.col-xs-12.col-sm-3').text.squish.split[6])
      rescue
        nil
      end
    skip_ad =
      if  page.search('h2.headline-key-facts').last.text.squish.delete('€').to_i > 500 ||
          table.search('td').last.text.squish.delete('€').to_i > 1000 ||
          (date_to.present? && date_to > 6.months.from_now)
        @skipped_rooms << { title: adv_link.text.squish, href: @base_url + adv_link.href }
        true
      else
        false
      end
    skip_ad
  end

  def write_interesting_rooms_to_files
    column_headers = %w[title href name phone_number size cost caution address date_from date_to looking_for description]
    CSV.open('interesting_rooms.csv', 'w', write_headers: true, headers: column_headers) do |writer|
      @interesting_rooms.each do |room|
        writer << [room[:title], room[:href], room[:name], room[:phone_number], room[:size], room[:cost], room[:caution], room[:address], room[:date_from], room[:date_to], room[:looking_for], room[:description]]
      end
    end
  end

  def write_skipped_rooms_to_files
    column_headers = %i[title href]
    CSV.open('skipped_rooms.csv', 'w', write_headers: true, headers: column_headers) do |writer|
      @skipped_rooms.each do |room|
        writer << [room[:title], room[:href]]
      end
    end
  end
end
