require 'spec_helper'

describe Griddler::Sendgrid::Adapter do
  it 'registers itself with griddler' do
    Griddler.adapter_registry[:sendgrid].should eq Griddler::Sendgrid::Adapter
  end
end

describe Griddler::Sendgrid::Adapter, '.normalize_params' do
  it_should_behave_like 'Griddler adapter',
    :sendgrid,
    {
      text: 'hi',
      to: 'Hello World <hi@example.com>',
      cc: 'emily@example.com',
      from: 'There <there@example.com>',
      charsets: { to: 'UTF-8', text: 'iso-8859-1' }.to_json
    }

  it 'changes attachments to an array of files' do
    normalized_params = normalize_params(attachment_params)
    normalized_params[:attachments].should eq [upload_1, upload_2]
  end

  it "uses sendgrid attachment info for filename" do
    attachments = normalize_params(attachment_params)[:attachments]

    attachments.first.original_filename.should eq "sendgrid-filename1.gif"
    attachments.second.original_filename.should eq "sendgrid-filename2.jpg"
  end

  it "uses data in sendgrid attachment-info for vendor specific" do
    normalized_params = normalize_params(attachment_params)
    normalized_params.should have_key(:vendor_specific)
    normalized_params[:vendor_specific].should have_key(:attachment_info)

    attachement1_info = normalized_params[:vendor_specific][:attachment_info].find do |at_info|
      at_info[:content_id] == "8ff183d1-1dbf-46ad-b4d8-b4900a4d108e"
    end

    attachement1_info.should be_present
    attachement1_info[:type].should eq "image/gif"
    attachement1_info[:file].should eq normalized_params[:attachments].first
  end

  it 'has no attachments' do
    params = default_params.merge(attachments: '0')

    normalized_params = normalize_params(params)
    normalized_params[:attachments].should be_empty
  end

  it 'splits to into an array' do
    normalized_params = normalize_params(default_params)

    normalized_params[:to].should eq [
      '"Mr Fugushima at Fugu, Inc" <hi@example.com>',
      'Foo bar <foo@example.com>',
      '"Eichhörnchen" <squirrel@example.com>',
      'no-name@example.com',
    ]
  end

  it 'wraps cc in an array' do
    normalized_params = normalize_params(default_params)

    normalized_params[:cc].should eq [default_params[:cc]]
  end

  it 'returns an array even if cc is empty' do
    params = default_params.merge(cc: nil)
    normalized_params = normalize_params(params)

    normalized_params[:cc].should eq []
  end

  it 'returns an array even if bcc is an empty string' do
    params = default_params.merge(envelope: '')
    normalized_params = normalize_params(params)

    normalized_params[:bcc].should eq []
  end

  it 'wraps bcc in an array' do
    normalized_params = normalize_params(default_params)

    normalized_params[:bcc].should eq ["johny@example.com"]
  end

  it 'returns an array even if bcc is empty' do
    params = default_params.merge(envelope: nil)
    normalized_params = normalize_params(params)

    normalized_params[:bcc].should eq []
  end

  it 'returns an empty array when the envelope to is the same as the base to' do
    params = default_params.merge(envelope: "{\"to\":[\"hi@example.com\"]}")
    normalized_params = normalize_params(params)

    normalized_params[:bcc].should eq []
  end

  it 'returns the charsets as a hash' do
    normalized_params = normalize_params(default_params)
    charsets = normalized_params[:charsets]

    charsets.should be_present
    charsets[:text].should eq 'iso-8859-1'
    charsets[:to].should eq 'UTF-8'
  end

  it 'does not explode if charsets is not JSON-able' do
    params = default_params.merge(charsets: 'This is not JSON')

    normalize_params(params)[:charsets].should eq({})
  end

  it 'does not explode if address is not parseable' do
    params = default_params.merge(cc: '"Closing Bracket Missing For Some Reason" <hi@example.com')

    normalize_params(params)[:cc].should eq([])
  end

  it 'defaults charsets to an empty hash if it is not specified in params' do
    params = default_params.except(:charsets)
    normalize_params(params)[:charsets].should eq({})
  end

  it 'normalizes the spam report into a griddler friendly format' do
    normalized_params = normalize_params(default_params)

    normalized_params[:spam_report].should eq({
      score: '1.234',
      report: 'Some spam report',
    })
  end

  def default_params
    {
      text: 'hi',
      to: '"Mr Fugushima at Fugu, Inc" <hi@example.com>, Foo bar <foo@example.com>, Eichhörnchen <squirrel@example.com>, <no-name@example.com>',
      cc: 'cc@example.com',
      from: 'there@example.com',
      envelope: "{\"to\":[\"johny@example.com\"], \"from\": [\"there@example.com\"]}",
      charsets: { to: 'UTF-8', text: 'iso-8859-1' }.to_json,
      spam_score: '1.234',
      spam_report: 'Some spam report'
    }
  end

  def attachment_params
    default_params.merge(
      attachments: '2',
      attachment1: upload_1,
      attachment2: upload_2,
     'attachment-info' => attachment_info
    )
  end

  def attachment_info
    <<-eojson
      {
        "attachment2": {
          "filename": "sendgrid-filename2.jpg",
          "name": "photo2.jpg",
          "type": "image/jpeg"
        },
        "attachment1": {
          "filename": "sendgrid-filename1.gif",
          "name": "photo1.gif",
          "type": "image/gif",
          "content-id": "8ff183d1-1dbf-46ad-b4d8-b4900a4d108e"
        }
      }
    eojson
  end
end
