require 'prawn'
require 'prawn/table'

class DepartmentReportPdfService
  include ActionView::Helpers::NumberHelper
  
  def initialize(department)
    @department = department
  end
  
  def generate_member_stats_pdf(data)
    Prawn::Document.new(page_size: 'A4', margin: [50, 50, 50, 50]) do |pdf|
      # Header
      pdf.font_size 24
      pdf.text "Member Statistics Report", align: :center, style: :bold
      pdf.font_size 14
      pdf.text "#{@department.name} (#{@department.code})", align: :center
      pdf.text "Generated on #{Time.current.strftime('%B %d, %Y at %I:%M %p')}", align: :center
      pdf.move_down 30
      
      # Summary Statistics
      pdf.font_size 18
      pdf.text "Summary Statistics", style: :bold
      pdf.move_down 15
      
      summary_data = [
        ["Metric", "Count", "Percentage"],
        ["Total Members", data[:total_members], "100%"],
        ["Active Members", data[:active_members], "#{number_to_percentage(data[:active_members].to_f / data[:total_members] * 100, precision: 1)}"],
        ["Teachers", data[:teachers], "#{number_to_percentage(data[:teachers].to_f / data[:total_members] * 100, precision: 1)}"],
        ["Students", data[:students], "#{number_to_percentage(data[:students].to_f / data[:total_members] * 100, precision: 1)}"],
        ["Admins", data[:admins], "#{number_to_percentage(data[:admins].to_f / data[:total_members] * 100, precision: 1)}"]
      ]
      
      pdf.table(summary_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'E3F2FD'
        cells.borders = [:top, :bottom, :left, :right]
        cells.padding = 8
      end
      
      pdf.move_down 30
      
      # Role Distribution
      pdf.font_size 18
      pdf.text "Role Distribution", style: :bold
      pdf.move_down 15
      
      role_data = [["Role", "Count", "Percentage"]]
      data[:role_distribution].each do |role, count|
        percentage = data[:total_members] > 0 ? (count.to_f / data[:total_members] * 100).round(1) : 0
        role_data << [role, count, "#{percentage}%"]
      end
      
      pdf.table(role_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'E8F5E8'
        cells.borders = [:top, :bottom, :left, :right]
        cells.padding = 8
      end
      
      pdf.move_down 30
      
      # Status Distribution
      pdf.font_size 18
      pdf.text "Member Status", style: :bold
      pdf.move_down 15
      
      status_data = [["Status", "Count", "Percentage"]]
      data[:status_distribution].each do |status, count|
        percentage = data[:total_members] > 0 ? (count.to_f / data[:total_members] * 100).round(1) : 0
        status_data << [status, count, "#{percentage}%"]
      end
      
      pdf.table(status_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'FFF3E0'
        cells.borders = [:top, :bottom, :left, :right]
        cells.padding = 8
      end
      
      # Recent Additions (if any)
      if data[:recent_members]&.any?
        pdf.start_new_page
        pdf.font_size 18
        pdf.text "Recent Additions (Last #{data[:date_range]} Days)", style: :bold
        pdf.move_down 15
        
        recent_data = [["Name", "Email", "Role", "Joined Date"]]
        data[:recent_members].each do |member|
          recent_data << [
            "#{member.first_name} #{member.last_name}",
            member.email,
            member.role.humanize,
            member.created_at.strftime('%Y-%m-%d')
          ]
        end
        
        pdf.table(recent_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = 'F3E5F5'
          cells.borders = [:top, :bottom, :left, :right]
          cells.padding = 6
          cells.size = 10
        end
      end
      
      # Member Growth Chart (text representation)
      if data[:member_growth].any?
        pdf.start_new_page
        pdf.font_size 18
        pdf.text "Member Growth Over Time", style: :bold
        pdf.move_down 15
        
        growth_data = [["Month", "Total Members"]]
        data[:member_growth].each do |month, count|
          growth_data << [month, count]
        end
        
        pdf.table(growth_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = 'E1F5FE'
          cells.borders = [:top, :bottom, :left, :right]
          cells.padding = 8
        end
      end
      
      # Footer
      pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 150, 0], width: 150, align: :right, size: 10
    end
  end
  
  def generate_activity_summary_pdf(data)
    Prawn::Document.new(page_size: 'A4', margin: [50, 50, 50, 50]) do |pdf|
      # Header
      pdf.font_size 24
      pdf.text "Activity Summary Report", align: :center, style: :bold
      pdf.font_size 14
      pdf.text "#{@department.name} (#{@department.code})", align: :center
      pdf.text "Generated on #{Time.current.strftime('%B %d, %Y at %I:%M %p')}", align: :center
      pdf.move_down 30
      
      # Summary Statistics
      pdf.font_size 18
      pdf.text "Activity Overview", style: :bold
      pdf.move_down 15
      
      activity_data = [
        ["Activity Type", "Total", "Recent (#{data[:date_range]} days)"],
        ["Announcements", data[:total_announcements], data[:recent_announcements].count],
        ["Published Announcements", data[:published_announcements], "N/A"],
        ["Pinned Announcements", data[:pinned_announcements], "N/A"],
        ["Shared Content", data[:total_shared_content], data[:recent_content].count],
        ["Member Changes", "N/A", data[:member_changes]],
        ["New Members", "N/A", data[:new_members]]
      ]
      
      pdf.table(activity_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'E3F2FD'
        cells.borders = [:top, :bottom, :left, :right]
        cells.padding = 8
      end
      
      pdf.move_down 30
      
      # Recent Announcements
      if data[:recent_announcements].any?
        pdf.font_size 18
        pdf.text "Recent Announcements", style: :bold
        pdf.move_down 15
        
        announcement_data = [["Title", "Status", "Author", "Created"]]
        data[:recent_announcements].each do |announcement|
          announcement_data << [
            announcement.title,
            announcement.published? ? "Published" : "Draft",
            announcement.user.full_name,
            announcement.created_at.strftime("%b %d, %Y")
          ]
        end
        
        pdf.table(announcement_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = 'E8F5E8'
          cells.borders = [:top, :bottom, :left, :right]
          cells.padding = 6
          cells.size = 10
        end
        
        pdf.move_down 20
      end
      
      # Recent Content
      if data[:recent_content].any?
        pdf.font_size 18
        pdf.text "Recent Shared Content", style: :bold
        pdf.move_down 15
        
        content_data = [["Type", "Shared By", "Action", "Date"]]
        data[:recent_content].each do |content|
          content_data << [
            content.shareable_type,
            content.shared_by.full_name,
            content.action.capitalize,
            content.created_at.strftime("%b %d, %Y")
          ]
        end
        
        pdf.table(content_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = 'FFF3E0'
          cells.borders = [:top, :bottom, :left, :right]
          cells.padding = 6
          cells.size = 10
        end
      end
      
      # Daily Activity Chart (if data exists)
      if data[:daily_activity]&.any?
        pdf.start_new_page
        pdf.font_size 18
        pdf.text "Daily Activity Breakdown", style: :bold
        pdf.move_down 15
        
        daily_data = [["Date", "Total Activities"]]
        data[:daily_activity].each do |date, count|
          daily_data << [date, count]
        end
        
        pdf.table(daily_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = 'F3E5F5'
          cells.borders = [:top, :bottom, :left, :right]
          cells.padding = 8
        end
      end
      
      # Footer
      pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 150, 0], width: 150, align: :right, size: 10
    end
  end
  
  def generate_content_report_pdf(data)
    Prawn::Document.new(page_size: 'A4', margin: [50, 50, 50, 50]) do |pdf|
      # Header
      pdf.font_size 24
      pdf.text "Content Sharing Report", align: :center, style: :bold
      pdf.font_size 14
      pdf.text "#{@department.name} (#{@department.code})", align: :center
      pdf.text "Generated on #{Time.current.strftime('%B %d, %Y at %I:%M %p')}", align: :center
      pdf.move_down 30
      
      # Summary Statistics
      pdf.font_size 18
      pdf.text "Content Overview", style: :bold
      pdf.move_down 15
      
      summary_data = [
        ["Metric", "Count"],
        ["Total Content Shared", data[:total_content]],
        ["Recent Content (#{data[:date_range]} days)", data[:recent_content].count],
        ["Content Types", data[:content_by_type].keys.count],
        ["Active Sharers", data[:top_sharers].count]
      ]
      
      pdf.table(summary_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'E3F2FD'
        cells.borders = [:top, :bottom, :left, :right]
        cells.padding = 8
      end
      
      pdf.move_down 30
      
      # Content by Type
      if data[:content_by_type].any?
        pdf.font_size 18
        pdf.text "Content by Type", style: :bold
        pdf.move_down 15
        
        type_data = [["Content Type", "Count", "Percentage"]]
        total_recent = data[:recent_content].count
        data[:content_by_type].sort_by { |_, count| -count }.each do |type, count|
          percentage = total_recent > 0 ? (count.to_f / total_recent * 100).round(1) : 0
          type_data << [type, count, "#{percentage}%"]
        end
        
        pdf.table(type_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = 'E8F5E8'
          cells.borders = [:top, :bottom, :left, :right]
          cells.padding = 8
        end
        
        pdf.move_down 30
      end
      
      # Top Sharers
      if data[:top_sharers].any?
        pdf.font_size 18
        pdf.text "Top Content Sharers", style: :bold
        pdf.move_down 15
        
        sharer_data = [["Rank", "Name", "Shares", "Percentage"]]
        total_shares = data[:top_sharers].sum { |_, count| count }
        data[:top_sharers].each_with_index do |(name, count), index|
          percentage = total_shares > 0 ? (count.to_f / total_shares * 100).round(1) : 0
          sharer_data << [
            "##{index + 1}",
            name,
            count,
            "#{percentage}%"
          ]
        end
        
        pdf.table(sharer_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = 'FFF3E0'
          cells.borders = [:top, :bottom, :left, :right]
          cells.padding = 8
        end
        
        pdf.move_down 30
      end
      
      # Recent Content Details
      if data[:recent_content].any?
        pdf.start_new_page
        pdf.font_size 18
        pdf.text "Recent Content Details", style: :bold
        pdf.move_down 15
        
        content_data = [["Type", "Shared By", "Action", "Date"]]
        data[:recent_content].limit(20).each do |content|
          content_data << [
            content.shareable_type,
            content.shared_by.full_name,
            content.action.capitalize,
            content.created_at.strftime("%b %d, %Y at %I:%M %p")
          ]
        end
        
        pdf.table(content_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = 'F3E5F5'
          cells.borders = [:top, :bottom, :left, :right]
          cells.padding = 6
          cells.size = 9
        end
        
        if data[:recent_content].count > 20
          pdf.move_down 10
          pdf.font_size 10
          pdf.text "Note: Showing 20 of #{data[:recent_content].count} items. Full list available in CSV export.", style: :italic
        end
      end
      
      # Footer
      pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 150, 0], width: 150, align: :right, size: 10
    end
  end
  
  def generate_comprehensive_pdf(member_data, activity_data, content_data)
    Prawn::Document.new(page_size: 'A4', margin: [50, 50, 50, 50]) do |pdf|
      # Cover Page
      pdf.font_size 28
      pdf.text "Comprehensive Department Report", align: :center, style: :bold
      pdf.move_down 20
      pdf.font_size 20
      pdf.text "#{@department.name}", align: :center, style: :bold
      pdf.font_size 16
      pdf.text "Department Code: #{@department.code}", align: :center
      pdf.move_down 30
      pdf.font_size 14
      pdf.text "Generated on #{Time.current.strftime('%B %d, %Y at %I:%M %p')}", align: :center
      
      pdf.move_down 50
      
      # Table of Contents
      pdf.font_size 18
      pdf.text "Table of Contents", style: :bold
      pdf.move_down 15
      pdf.font_size 12
      pdf.text "1. Member Statistics Report"
      pdf.text "2. Activity Summary Report"
      pdf.text "3. Content Sharing Report"
      
      # Member Statistics Section
      pdf.start_new_page
      pdf.font_size 20
      pdf.text "1. Member Statistics Report", style: :bold
      pdf.move_down 20
      
      # Include member stats content (simplified)
      summary_data = [
        ["Metric", "Count"],
        ["Total Members", member_data[:total_members]],
        ["Active Members", member_data[:active_members]],
        ["Teachers", member_data[:teachers]],
        ["Students", member_data[:students]]
      ]
      
      pdf.table(summary_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'E3F2FD'
        cells.borders = [:top, :bottom, :left, :right]
        cells.padding = 8
      end
      
      # Activity Summary Section
      pdf.start_new_page
      pdf.font_size 20
      pdf.text "2. Activity Summary Report", style: :bold
      pdf.move_down 20
      
      activity_summary = [
        ["Activity Type", "Count"],
        ["Total Announcements", activity_data[:total_announcements]],
        ["Shared Content", activity_data[:total_shared_content]],
        ["Member Changes", activity_data[:member_changes]]
      ]
      
      pdf.table(activity_summary, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'E8F5E8'
        cells.borders = [:top, :bottom, :left, :right]
        cells.padding = 8
      end
      
      # Content Report Section
      pdf.start_new_page
      pdf.font_size 20
      pdf.text "3. Content Sharing Report", style: :bold
      pdf.move_down 20
      
      content_summary = [
        ["Metric", "Count"],
        ["Total Content", content_data[:total_content]],
        ["Content Types", content_data[:content_by_type].keys.count],
        ["Active Sharers", content_data[:top_sharers].count]
      ]
      
      pdf.table(content_summary, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'FFF3E0'
        cells.borders = [:top, :bottom, :left, :right]
        cells.padding = 8
      end
      
      # Footer
      pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 150, 0], width: 150, align: :right, size: 10
    end
  end
end