require 'mongo'

 server="localhost"
 test_db='ibm_test_db'
 collection='mongodb_ruby_driver_2_x'

 server_addr=server + ":27017"

 Mongo::Logger.logger.level = ::Logger::FATAL   # hide DEBUG logging

 db = Mongo::Client.new([ server_addr ], :database => test_db)

 db[:collection].drop

 result = db[:collection].insert_one({ company: 'IBM' , project: 'MongoDB Driver', language: 'Ruby', version: '2.12.1'})

 3.times { |i| db[:collection].insert_one({ _id: i+1, line: i+1 }) }

 db[:collection].find().each do |document|
    printf("%s\n", document) #=> Yields a BSON::Document.
 end
