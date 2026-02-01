# Fix for the zoho_zeptomail-rails gem which incorrectly strips HTML tags
# in its msg_html method, destroying email designs.

require "zoho_zeptomail-rails"
require "zohozeptomail_mailer"

module ZohozeptomailRails
  class RailsMsgToMsMsg
    def self.msg_html(msg)
      html_parts = []
      if msg.multipart?
        msg.parts.each do |part|
          if part.content_type =~ /^multipart\/alternative/i
            html_parts.concat(extract_text_html_multipart_alternative(part))
          elsif part.content_type =~ /^text\/html[;$]/i
            html_parts << part.body.decoded.to_s.strip
          end
        end
      end

      if msg.mime_type =~ /^text\/html$/i
        html_parts << msg.body.decoded.to_s.strip
      end

      # BUG FIX: We removed the .gsub(/<\/?[^>]*>/, '') which was stripping all HTML tags!
      html_parts.join("<br>").strip
    end
  end
end
