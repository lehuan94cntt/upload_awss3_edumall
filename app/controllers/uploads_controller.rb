class UploadsController < ApplicationController
  require 'aws-sdk'
  def new
    @aws_signature = AwsServices.generate_signature
  end

  def create
    @aws_signature = AwsServices.generate_signature

    aws = aws_response_parser(params[:aws_response])

    job_id = ''
    job_id = create_job(aws[:key]).id if aws[:bucket] == BUCKET_VIDEO

    uploader = Upload.create(aws)

    if uploader.save
      render json: { success: true, message: 'success!' }
    else
      render json: { success: false, message: uploader.errors.to_json }
    end
  end

  def index
    @aws_signature = AwsServices.generate_signature
    @uploads = Upload.where(:type => 'video')
  end

  def view_image
    @image = Upload.where(:type => 'image')
  end

  def listen_audio
    @audio = Upload.where(:type => 'audio')
  end

  def document
    @document = Upload.where(:type => 'document')
  end

  private

  def create_job(key)
    job = AwsServices::Job.generate(key)
    result = TRANSCODER.create_job(job)

    result.job
  end

  def aws_response_parser(response)
    result = Hash.from_xml(response)
    result = result['PostResponse']

    file_name = result['Key'].split('/').last

    {
      url: result['Location'],
      key: result['Key'],
      name: file_name,
      bucket: result['Bucket']
    }
  end

  def validate_create_job
    if params[:aws_response].blank?
      render json: { success: false, message: 'Missing params!' }
      return
    end
  end

  def validate_update_job
    @sns = JSON.parse(request.body.read)

    if @sns.blank? || @sns['Type'] != 'Notification'
      render text: '', status: 422
      return
    end

    @message = JSON.parse(@sns['Message'])
  end

  def update_session
    session[:media] = params[:media].strip unless params[:media].blank?

    session[:media] = 'all' if session[:media].blank?
  end

  def build_condition
    # Update and clear session
    update_session

    condition = {}
    condition[:type] = session[:media] unless session[:media] == 'all'

    fields = [:name, :thumbnail, :url, :created_at, :type]
    Upload.where(condition).only(fields).desc(:created_at)
  end

  def view_upload
    @upload = build_condition
  end
end