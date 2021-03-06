task 'manifest:update' do
  tempdir do |dir|
    File.open('VERSION', 'w') do |file|
      file.puts version
    end
    puts "Current version: #{version}"
    s3_store "#{dir}/VERSION", 'do_snapshot/VERSION'
  end
end
