class ReportMailer < ApplicationMailer
  default from: 'noreply@uni-hub.edu'
  
  def generation_completed(report)
    @report = report
    @user = report.user
    @dashboard_url = analytics_report_url(@report)
    
    mail(
      to: @user.email,
      subject: "Report '#{@report.title}' Generated Successfully"
    )
  end
  
  def generation_failed(report, error_message)
    @report = report
    @user = report.user
    @error_message = error_message
    @retry_url = regenerate_analytics_report_url(@report)
    
    mail(
      to: @user.email,
      subject: "Report Generation Failed: #{@report.title}"
    )
  end
  
  def scheduled_report_ready(report)
    @report = report
    @user = report.user
    @download_url = export_analytics_report_url(@report, format: 'pdf')
    
    mail(
      to: @user.email,
      subject: "Scheduled Report: #{@report.title}"
    )
  end
end