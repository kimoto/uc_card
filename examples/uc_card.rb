#!/bin/env ruby
# encoding: utf-8
# Author: kimoto
require 'uc_card'
UCCard.start_with_pit("uccard.co.jp") do |card|
  puts card
end

