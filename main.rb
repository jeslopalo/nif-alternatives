#!/usr/bin/env jruby 
#--dev

class Event

  def initialize(values)
    @fields= values
  end

  def get(key)
    @fields[key]
  end

  def set(key, value)
    @fields[key]= value
  end

  def to_hash
    @fields.clone
  end

end

class NifAlternativesGenerator

  NIF_MAX_LENGTH=9

  def initialize(source, target)
    @source=source
    @target=target
  end

  def combine(prefix, digits, crc)
    combinations=[]

    combinations << prefix + digits + crc if prefix && crc
    combinations << prefix + digits if prefix
    combinations << digits + crc if crc
    combinations << digits if digits
  end

  def normalize(value)
    value.gsub(/[^0-9a-z ]/i, '').upcase if value
  end

  def generate(event)
    source_value= normalize event.get(@source)
    # match= source_value.match(/(^[a-z]?)([0-9]{0,7}[1-9])([a-z]?$)/i)
    match= source_value.match(/(?=.{2,9}$)(^[a-z]?)([0-9]{0,8}[1-9][0-9]{0,8})([a-z]?$)/i)

    if match && source_value.length <= NIF_MAX_LENGTH

      prefix, digits, control= match.captures
      number_of_non_digits= (prefix.to_s.length + control.to_s.length)
      digits.sub!(/^0+/, '')

      if number_of_non_digits > 0

        info= {
            :info => {
                :prefijo => prefix,
                :digitos => digits,
                :control => control
            }
        }

        alternatives= []

        (NIF_MAX_LENGTH - number_of_non_digits).times do
        |length|
          alternatives.concat combine(prefix, digits.rjust(length+1, '0'), control)
        end

        info[:combinaciones]= alternatives.uniq
        event.set(@target, info)
      end

    end

    event
  end
end


class Main

  def initialize(source, target)
    @generator=NifAlternativesGenerator.new source, target
  end

  def print(candidate, event)

    values= event.to_hash

    if values[:alternativas]
      puts "\nCalculando las diferentes variaciones del nif '#{candidate}'..."

      puts '╔═════════════════════════════════════╦╦══════════════════════╦════════════╦════════════╦════════════╗'
      printf "║ %35s ║║ %20s ║ %10s ║ %10s ║ %10s ║\n", 'NIF', 'NORMALIZADO', 'PREFIJO', 'DIGITOS', 'CONTROL'
      puts '╠═════════════════════════════════════╬╬══════════════════════╬════════════╬════════════╬════════════╣'
      printf "║ %35s ║║ %20s ║ %10s ║ %10s ║ %10s ║\n", candidate, values[:nif], values[:alternativas][:info][:prefijo], values[:alternativas][:info][:digitos], values[:alternativas][:info][:control]
      puts '╠═════════════════════════════════════╩╩══════════════════════╩════════════╩════════════╩════════════╣'
      printf "║ %-98s ║\n", 'COMBINACIONES'
      puts '╠════════════════════════════════════════════════════════════════════════════════════════════════════╣'

      if (values[:alternativas][:info][:prefijo].to_s.length + values[:alternativas][:info][:control].to_s.length) == 2
        output = values[:alternativas][:combinaciones].each_slice(4).to_a
        output.each do |x|
          printf "║  %23s %23s %23s %23s   ║\n", *(x.fill('', x.length...4))
        end
      else
        output = values[:alternativas][:combinaciones].each_slice(2).to_a
        output.each do |x|
          printf "║ %48s  %48s ║\n", *(x.fill('', x.length...2))
        end
      end

      puts '╚════════════════════════════════════════════════════════════════════════════════════════════════════╝'
    else
      puts "'#{candidate}' no tiene posibles alternativas o no parece un nif"
    end

  end

  def main(argv)

    unless argv.length > 0
      puts 'error: el nif es obligatorio!'
      return 1
    end

    argv.each do |candidate|

      completed_event=@generator.generate Event.new({:nif => @generator.normalize(candidate)})

      print candidate, completed_event
    end

  end

end

Main.new(:nif, :alternativas).main ARGV
