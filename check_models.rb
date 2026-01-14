require 'net/http'
require 'uri'
require 'json'

api_key = "AIzaSyAoqmmQ37xZ2Dt9JM4g3iZL9HBP73lWgaU" # Put your key here temporarily
uri = URI("https://generativelanguage.googleapis.com/v1/models?key=#{api_key}")
response = Net::HTTP.get(uri)
models = JSON.parse(response)

puts "--- AVAILABLE MODELS ---"
models['models'].each { |m| puts m['name'] }