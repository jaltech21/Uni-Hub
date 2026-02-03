#!/usr/bin/env ruby
require_relative 'config/environment'

begin
  puts "Testing Schedule.available_for_enrollment..."
  schedules = Schedule.available_for_enrollment
                     .includes(:instructor, :department)
                     .order(:course)
  
  puts "Query built successfully. Total schedules: #{schedules.count}"
  
  puts "\nIterating through schedules..."
  schedules.each_with_index do |schedule, index|
    puts "Schedule #{index + 1}:"
    puts "  - course_code: #{schedule.course_code}"
    puts "  - title: #{schedule.title}"
    puts "  - instructor: #{schedule.instructor&.full_name}"
    puts "  - department: #{schedule.department&.name}"
  end
  
  puts "\nTest completed successfully!"
rescue => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts "\nBacktrace:"
  puts e.backtrace.first(10)
end
