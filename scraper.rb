# encoding: utf-8

require 'rubygems'
require 'scraperwiki'
require 'mechanize'
require 'nokogiri'

BASE_URL="http://www.hzs.sk/horska-zachranna-sluzba/smrtelne-nehody-"

@agent = Mechanize.new { |agent|
  agent.user_agent_alias = 'Mac Safari'
}

def parse_date(date)
  date.strip!
  return "#{$1}-unknown" if date =~ /^(\d{4})\-/
  return "#{$3}-#{$2}-#{$1}" if date =~ /^(\d{1,2})\.(\d{1,2})\.(\d{4})/
  return "#{$1}-#{$2}-#{$3}" if date =~ /^(\d{4}) .{1} (\d{1,2})\.(\d{1,2})\./
  return "#{$1}-#{$2}-#{$3}" if date =~ /^(\d{4}) \- (\d{1,2})\.(\d{1,2})/
  return "#{$1}-#{$2}-#{$3}" if date =~ /^(\d{4}) \- (\d{1,2})\. (\d{1,2})\./
  return "#{date}-unknown" if date =~ /^(\d{4})/
  return date if date =~ /pol.*stor/
end

def parse_dash_line(line)
  m1, m2, m3, m4, m5 =
    line.match(/^(\d+\.\d+\.\d+)[ -]+([^\d]+)[ -](\d+)[ -]+ročn[ýá]+[ -]+([A-Z]{2})[\s-]*(.*)$/).captures

  date = parse_date(m1)
  victim = m2.gsub(/ -$/, '')

  row = {
    "date" => date,
    "victim" => victim,
    "age" => m3,
    "location" => m4,
    "accident_information" => m5,
  }

  return row
end

def parse_line(a)
  line = {
    "date" => parse_date(a[0]) || 'unknown',
  }
  if line["date"] == 'unknown'
    i = 0
  else
    i = 1
  end

  victim = a[i].strip
  age = a[i+1].strip rescue nil

  if (age && age !~ /^\d+$/)
    age = nil
    i -= 1
  end

  location = a[i+2].strip rescue nil
  accident = a[i+3].strip rescue ''

  i += 4
  for j in i..a.length-1 do
    accident += ', ' + a[j].strip rescue ''
  end

  if accident == ''
    accident = nil
  end

  line.merge!(
    "victim" => victim,
    "age" => age,
    "location" => location,
    "accident_information" => accident
  )

  line
end

def scrap_statistics
  locations = ['Vysoke Tatry', 'Nizke Tatry', 'Zapadne Tatry', 'Mala Fatra', 'Velka Fatra', 'Slovensky Raj']

  locations.each do |region|
    region_part = region.downcase.sub(' ', '-')

    @agent.get(BASE_URL + region_part) do |page|
      page.search('#table td').each do |item|
        if item.text =~ /,.*,/
            yield parse_line(item.text.split(',')).merge("region" => region)
        else
            yield parse_dash_line(item.text).merge("region" => region)
        end
      end
    end
  end
end

scrap_statistics do |item|
  ScraperWiki.save_sqlite(unique_keys=["date", "victim"], data=item, table_name='deaths')
end
