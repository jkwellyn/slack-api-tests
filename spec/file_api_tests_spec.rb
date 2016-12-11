require 'faraday'
require 'logger'
require 'json'

module SlackApiTest
  context 'https://slack.com/api/' do
    before(:all) do
      @token = 'xoxp-111663727936-111663727968-111753979616-8a6c0acdf1596d98063c3e9ff05083a5'
      # let(:logger) { Logger.new(STDOUT) }
      @filename = 'puppy'
      @file_path = File.join(SUPPORT_PATH, "#{@filename}.png")
      @base_url = 'https://slack.com/api'
      @types = 'images'

      @connection = Faraday.new(@base_url) do |faraday|
        # faraday.response(:logger, logger, bodies: true)
        faraday.request(:url_encoded)
        faraday.request(:multipart)
        faraday.adapter(:net_http)
      end

      @headers = { 'Content-Type' => 'multipart/form-data' }
    end

    after(:each) do
      params = { token: @token,
                 types: @types }
      resp = @connection.get('files.list', params, @headers)
      @parsed_resp = JSON.parse(resp.body)

      wait 15 do
        @parsed_resp['files'].each do |x|
          params = { token: @token,
                     file: x['id'] }
          @connection.delete('files.delete', params, @headers)
        end
      end
    end

    describe '#file.load' do
      # Initial Uploading of .png file
      let(:resp_load) do
        params = { token: @token }
        params[:filename] = "#{@filename}.png"
        params[:file] = Faraday::UploadIO.new(@file_path, 'image/png')
        resp = @connection.post('files.upload', params, @headers)
        JSON.parse(resp.body)
      end

      it 'uploads .png file and create thumbnails' do
        expect(resp_load['ok']).to eq true
        expect(resp_load['file']['id'].empty?).to eq false
        expect(resp_load['file']['name']).to eq "#{@filename}.png"

        thumbnail_keys = %w(thumb_64 thumb_80 thumb_360 thumb_160)

        thumbnail_keys.each do |key|
          expect(resp_load['file'].keys).to include key
          expect(resp_load['file'][key]).to match /https\:\/\/files.slack.com\/files-tmb/
          expect(resp_load['file'][key]).to match /#{Regexp.quote(@filename)}/
        end
      end
    end

    describe '#file.list' do
      let(:resp_load) do
        params = { token: @token }
        params[:filename] = "#{@filename}.png"
        params[:file] = Faraday::UploadIO.new(@file_path, 'image/png')
        resp = @connection.post('files.upload', params, @headers)
        JSON.parse(resp.body)
      end

      # The list file.list api was exhibiting high lag time, so I added waits to ensure the existence of the files before running the test
      it 'uploaded is properly listed' do
        puts resp_load['file']['id']
        wait 30 do
          params_list = { token: @token,
                          types: @types }
          resp = @connection.get('files.list', params_list, @headers)
          resp_list = JSON.parse(resp.body)
          if resp_list['files'].empty?
            raise 'Could not find list of uploaded files'
          else
            expect(resp_list['files'][0]['id']).to eq (resp_load['file']['id'])
         end
        end
      end
    end

    describe '#file.delete' do
      let(:resp_load) do
        params = { token: @token }
        params[:filename] = "#{@filename}.png"
        params[:file] = Faraday::UploadIO.new(@file_path, 'image/png')
        resp = @connection.post('files.upload', params, @headers)
        JSON.parse(resp.body)
      end

      it 'delete uploaded file' do
        params = { token: @token }
        params[:file] = (resp_load['file']['id'])
        resp = @connection.delete('files.delete', params, @headers)
        parsed_resp = JSON.parse(resp.body)
        expect(parsed_resp['ok']).to eq true
      end

      it 'delete a file that was already deleted' do
        wait 15 do
          params = { token: @token }
          params[:file] = (resp_load['file']['id'])
          resp = @connection.delete('files.delete', params, @headers)
          parsed_resp = JSON.parse(resp.body)

          expect(parsed_resp['ok']).to eq false
          expect(parsed_resp['error']).to eq('file_deleted')
        end
      end
    end
  end
end
