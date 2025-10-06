namespace :words do
  desc "Delete all words from the database"
  task delete_all: :environment do
    count = Word.count

    if count == 0
      puts "No words to delete."
    else
      print "About to delete #{count} words. Are you sure? (yes/no): "
      confirmation = STDIN.gets.chomp.downcase

      if confirmation == "yes"
        Word.destroy_all
        puts "Successfully deleted #{count} words."
      else
        puts "Deletion cancelled."
      end
    end
  end

  desc "Force delete all words without confirmation (DANGEROUS!)"
  task force_delete_all: :environment do
    count = Word.count
    Word.destroy_all
    puts "Deleted #{count} words."
  end

  desc "Show word count"
  task count: :environment do
    puts "Total words: #{Word.count}"
  end
end
