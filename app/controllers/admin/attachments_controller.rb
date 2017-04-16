class Admin::AttachmentsController < Admin::BaseController
  # NOTE: bailing out of the inherited resources defaults as they would return a 422 error on
  #   upload :(
  #actions :create, :update, :destroy
  #defaults :resource_class => Attachment, :collection_name => "attachments", :instance_name => "attachment"

  respond_to :json, :html
  
  def index
    params[:page] ||= 1
    @attachments = Attachment.all.page(params[:page])
  end

  # FIXME: below is all WIP
  def show
    @attachment = Attachment.find(params[:id])
    respond_to do |format|
      format.json { render json: @attachment.as_json(methods: [:file_url, *AttachableWithMetadata::ATTACHMENT_METADATA_FIELDS.map { |m| "file_#{m}"}]) }
      format.html
    end
  end

  def create
    @attachment = Attachment.new()
    @attachment.file = params[:attachment][:file]
    respond_to do |format|
      format.json do
        if @attachment.save
          render json: @attachment.as_json(methods: [:file_url, *AttachableWithMetadata::ATTACHMENT_METADATA_FIELDS.map { |m| "file_#{m}"}])
        else
          render json: { errors: @attachment.errors.full_messages }
        end
      end
      format.html do
        if @attachment.save
          params[:attachment].except(:file).each do |metadata_field, value|
            @attachment.send "#{metadata_field}=", value
          end
          flash.now[:alert] = "Sucessfully saved attachment"
          render :template => "admin/attachments/show"
        else
          flash.now[:alert] = "We had some problems saving. Please check the form below."
          render :template => "admin/attachments/edit"
        end
      end
    end
  end

  def update
    @attachment = Attachment.find(params[:id])
    params[:attachment].each do |metadata_field, value|
      @attachment.send "#{metadata_field}=", value
    end
    respond_to do |format|
      format.json do
        if @attachment.save
          render json: @attachment.as_json(methods: [:file_url, *AttachableWithMetadata::ATTACHMENT_METADATA_FIELDS.map { |m| "file_#{m}"}])
        else
          render json: { errors: @attachment.errors.full_mesasges }
        end
      end
      format.html do
        unless @attachment.save
          flash.now[:alert] = "We had some problems saving. Please check the form below."
        end
        render :template => "admin/attachments/show"
      end
    end
  end

end
