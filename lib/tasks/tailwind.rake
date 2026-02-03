# lib/tasks/tailwind.rake
namespace :tailwindcss do
  desc "Build and compile Tailwind CSS"
  task :build do
    puts "Compiling Tailwind CSS..."
    system("npm run build:css")
    unless $?.success?
      raise "Tailwind CSS build failed. Check your package.json script and npm installation."
    end
    puts "Tailwind CSS compilation successful!"
  end
end