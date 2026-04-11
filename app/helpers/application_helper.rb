module ApplicationHelper
  include Pagy::Frontend

  def styled_form_with(**options, &block)
    options[:builder] = StyledFormBuilder
    form_with(**options, &block)
  end

  def icon(key, size: "md", color: "default", custom: false, as_button: false, **opts)
    extra_classes = opts.delete(:class)
    sizes = { xs: "w-3 h-3", sm: "w-4 h-4", md: "w-5 h-5", lg: "w-6 h-6", xl: "w-7 h-7", "2xl": "w-8 h-8" }
    colors = { default: "fg-gray", white: "fg-inverse", success: "text-success", warning: "text-warning", destructive: "text-destructive", current: "text-current" }

    icon_classes = class_names(
      "shrink-0",
      sizes[size.to_sym],
      colors[color.to_sym],
      extra_classes
    )

    if custom
      inline_svg_tag("#{key}.svg", class: icon_classes, **opts)
    elsif as_button
      render DS::Button.new(variant: "icon", class: extra_classes, icon: key, size: size, type: "button", **opts)
    else
      lucide_icon(key, class: icon_classes, **opts)
    end
  end

  # Convert alpha (0-1) to 8-digit hex (00-FF)
  def hex_with_alpha(hex, alpha)
    alpha_hex = (alpha * 255).round.to_s(16).rjust(2, "0")
    "#{hex}#{alpha_hex}"
  end

  def title(page_title)
    content_for(:title) { page_title }
  end

  def header_title(page_title)
    content_for(:header_title) { page_title }
  end

  def header_description(page_description)
    content_for(:header_description) { page_description }
  end

  def page_active?(path)
    current_page?(path) || (request.path.start_with?(path) && path != "/")
  end

  # Wrapper around I18n.l to support custom date formats
  def format_date(object, format = :default, options = {})
    date = object.to_date

    format_code = options[:format_code] || Current.family&.date_format

    if format_code.present?
      date.strftime(format_code)
    else
      I18n.l(date, format: format, **options)
    end
  end

  def format_money(number_or_money, options = {})
    return nil unless number_or_money

    Money.new(number_or_money).format(options)
  end

  def totals_by_currency(collection:, money_method:, separator: " | ", negate: false)
    collection.group_by(&:currency)
              .transform_values { |item| calculate_total(item, money_method, negate) }
              .map { |_currency, money| format_money(money) }
              .join(separator)
  end

  def show_super_admin_bar?
    if params[:admin].present?
      cookies.permanent[:admin] = params[:admin]
    end

    cookies[:admin] == "true"
  end

  # Custom Redcarpet renderer that keeps internal links in the same tab
  # and blocks dangerous URI schemes (javascript:, data:, vbscript:)
  class SmartLinkRenderer < Redcarpet::Render::HTML
    def link(link, title, content)
      safe_href = CGI.escapeHTML(link.to_s)
      return content unless safe_href.match?(%r{\Ahttps?://|\A/})

      if link.start_with?("/")
        %(<a href="#{safe_href}"#{title_attr(title)}>#{content}</a>)
      else
        %(<a href="#{safe_href}" target="_blank" rel="noopener noreferrer"#{title_attr(title)}>#{content}</a>)
      end
    end

    private

      def title_attr(title)
        title ? %( title="#{CGI.escapeHTML(title)}") : ""
      end
  end

  # Renders Markdown text using Redcarpet
  def markdown(text)
    return "" if text.blank?

    renderer = SmartLinkRenderer.new(hard_wrap: true)

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      underline: true,
      highlight: true,
      quote: true,
      footnotes: true
    )

    markdown.render(normalize_markdown(text)).html_safe
  end

  private
    # Inserts missing blank lines before markdown block elements (headers, lists)
    # so Redcarpet parses them correctly. LLMs sometimes omit required blank lines.
    def normalize_markdown(text)
      header = /\A\#{1,4}\s/
      list_item = /\A[-*]\s|\A\d+\.\s/

      # Split headers glued to preceding text onto their own lines
      # e.g. "some text### Header" → "some text\n### Header"
      text = text.gsub(/([^\s#])(\#{1,4}\s)/, "\\1\n\\2")

      # Split concatenated pseudo-list items where a word char is followed by "- " and a letter/bracket
      # e.g. "Summary- Period:" → "Summary\n- Period:"
      # Avoids splitting negative numbers (-$500), date ranges, or URLs
      text = text.gsub(/(\w)(-\s+[A-Za-z\[*#])/, "\\1\n\\2")

      # Ensure headers and the first list item in a group have a blank line before them
      lines = text.split("\n", -1)
      result = []

      lines.each_with_index do |line, i|
        next (result << line) if i == 0

        prev = result.last
        needs_blank = if line.match?(header)
          prev != ""
        elsif line.match?(list_item)
          prev.present? && !prev.match?(list_item)
        end

        result << "" if needs_blank
        result << line
      end

      result.join("\n")
    end

    def calculate_total(item, money_method, negate)
      # Filter out transfer-type transactions from entries
      # Only Entry objects have entryable transactions, Account objects don't
      items = item.reject do |i|
        i.is_a?(Entry) &&
        i.entryable.is_a?(Transaction) &&
        i.entryable.transfer?
      end
      total = items.sum(&money_method)
      negate ? -total : total
    end
end
