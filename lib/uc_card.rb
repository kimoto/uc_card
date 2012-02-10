require 'nokogiri'
require 'mechanize'
require 'logger'
require 'pit'

class UCCard
  attr_reader :recent_shoppings

  def self.start(options={})
    instance=self.new(options)
    begin
      instance.login
      instance.go_recent
      yield instance
    ensure
      instance.logout
    end
  end

  def self.start_with_pit(pit_key, &block)
    config = Pit.get(pit_key, :require => {
      :user => 'your name',
      :password => 'your password'
    })
    self.start(:user => config[:user], :password => config[:password], &block)
  end

  def initialize(options={})
    @user = options[:user] or raise ArgumentError('user')
    @password = options[:password] or raise ArgumentError('password')

    ## data
    @recent_shoppings = []

    create_agent
  end

  ### login / logout
  def login
    @agent.get("https://atunet.uccard.co.jp/UCPc/welcomeSCR.do")
    @agent.page.form_with(:name => '_USA01Form'){ |f|
      f.field_with(:name => 'inputId').value = @user
      f.field_with(:name => 'inputPassword').value = @password
      f.click_button
    }
  end

  def logout
    @agent.get('https://atunet.uccard.co.jp/UCPc/USL0100BLC01.do?r=8400550016797730123')
  end

  def go_recent
    @agent.get("https://atunet.uccard.co.jp/UCPc/USC0101BLC01NOW.do?r=7005820039568205309")
    @recent_shoppings = []
    Nokogiri(@agent.page.body).search("#mainWrap > table > tbody > tr")[2..-1].each{ |record|
      (date, klass, name, value, usecase, times, note, payment) = record.search("td").map{|e| e.text.strip}
      @recent_shoppings << ShoppingData.new(
        :date => date, :klass => klass, :name => name,
        :value => value, :usecase => usecase, :times => times,
        :note => note, :payment => payment)
    }
  end

  ### api
  def reserved_payment
    recent_shoppings.inject(0) {|total, record|
      total += record.money
    }.to_i
  end

  def reserved_payment_this_month
  end

  def to_s
    recent_data = recent_shoppings.map(&:to_s).join($/)
    return <<-EOT
#{recent_data}
Total: #{reserved_payment}
    EOT
  end

  private
  def create_agent
    unless @agent
      @agent = Mechanize.new{ |agent|
        agent.user_agent_alias = "Windows IE 7"
      }
    end
  end
end

class UCCard::ShoppingData
  attr_accessor :date
  attr_accessor :klass
  attr_accessor :name
  attr_accessor :value
  attr_accessor :usecase
  attr_accessor :times
  attr_accessor :note
  attr_accessor :payment

  def initialize(options={})
    options.each{ |k,v|
      self.send("#{k.to_s}=", v)
    }
  end

  def money
    @value.gsub(/\D/, '').to_i
  end

  def to_s
    #"#{date}: " + [@date, @klass, @name, @value, @usecase, @times, @note, @payment].join(',')
    "#{@date}: #{@name} #{money} #{@usecase} #{@times}"
  end
end

