require 'net/smtp'

def email_admin(subject, message)
    if ADMINS.nil?
        STDERR.puts "No ADMINS defined"
        return
    end

    from = "Raindrops Service <raindrops@raindrops.mirror.centos.org>" 
    to   = ADMINS
    to_field = ADMINS.join(', ')

    msg = <<-END_OF_MESSAGE.gsub(/^ {4}/,"")
    From: #{from}
    To: #{to_field}
    Subject: #{subject}
        
    #{message}
    END_OF_MESSAGE

    Net::SMTP.start('localhost') do |smtp|
        smtp.send_message msg, from, to
    end
end
