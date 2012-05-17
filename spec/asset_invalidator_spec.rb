require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "GET /avatars/:klass/:id_part1/:id_part2/:id_part3/:filename" do
  before(:each) do
    File.stub!(:exists?).and_return(false)
    Resque.stub!(:enqueue)
  end

  def do_action
    get "/avatars/users/000/012/345/original.jpg?2352352352"
  end

  it "should check whether the file exists" do
    File.should_receive(:exists?).
      with("#{File.dirname(__FILE__)}/fixtures/avatars/users/000/012/345/original.jpg").
        and_return(false)
    do_action
  end

  it "should enqueue the resque task" do
    Resque.should_receive(:enqueue).
      with(S3FileCacheStoreTask,
           "http://foo.bar.com/avatars/users/000/012/345/original.jpg?2352352352",
           "#{File.dirname(__FILE__)}/fixtures/avatars/users/000/012/345/original.jpg")
    do_action
  end

  it "should respond with redirect" do
    do_action
    last_response.should be_redirect
    follow_redirect!
    last_request.url.should == "http://foo.bar.com/avatars/users/000/012/345/original.jpg?2352352352"
  end

  describe "when file exists" do
    before(:each) do
      File.stub!(:exists?).and_return(true)
    end

    it "should send the file" do
      do_action
      last_response.should be_ok
    end

    it "should have an image/jpeg content type" do
      do_action
      last_response.content_type.should == "image/jpeg"
    end
  end
end

describe "S3FileCacheStoreTask" do
  before(:each) do
    File.stub!(:exists?).and_return(false)
    @uri = URI.parse("http://foo.bar.com/avatars/users/000/012/345/original.jpg?2352352352")
    @response = mock("Net::HTTP::Response", :code => "404")
    Net::HTTP.stub!(:get_response).with(@uri).and_return(@response)
  end

  def do_action
    get "/avatars/users/000/012/345/original.jpg?2352352352"
  end

  it "should get response from the server uri" do
    Net::HTTP.should_receive(:get_response).with(@uri).
      and_return(@response)
    do_action
  end

  it "should create any directory" do
    FileUtils.should_not_receive(:mkpath)
    do_action
  end

  describe "when response code is 200" do
    before(:each) do
      @file = mock("File", :write => nil)
      @response.stub!(:code).and_return("200")
      @response.stub!(:body).and_return("terminator")
      FileUtils.stub!(:mkpath)
      File.stub!(:open).and_yield(@file)
    end

    it "should make the path" do
      FileUtils.should_receive(:mkpath).
        with("#{File.dirname(__FILE__)}/fixtures/avatars/users/000/012/345")
      do_action
    end

    it "should open the file for writing" do
      File.should_receive(:open).
        with("#{File.dirname(__FILE__)}/fixtures/avatars/users/000/012/345/original.jpg", "w").
          and_yield(@file)
      do_action
    end

    it "should write the response body to the file" do
      @file.should_receive(:write).with("terminator")
      do_action
    end
  end
end

describe "POST /invalidate/avatars/:klass/:id_part1/:id_part2/:id_part3/:filename" do
  def do_action
    post "/invalidate/avatars/users/000/012/345/original.jpg?2352352352"
  end

  describe "without a valid authentication" do
    before(:each) do
      authorize "frodo", "baggins"
    end

    it "should respond with status 401" do
      do_action
      last_response.status.should == 401
    end

    it "should respond with 'Not Authorized'" do
      do_action
      last_response.body.should =~ /Not Authorized/i
    end
  end

  describe "with a valid authentication" do
    before(:each) do
      authorize "username", "password"
      File.stub!(:exists?).and_return(false)
    end

    it "should check for file existence" do
      File.should_receive(:exists?).
        with("#{File.dirname(__FILE__)}/fixtures/avatars/users/000/012/345/original.jpg").
          and_return(false)
      do_action
    end

    it "should respond OK" do
      do_action
      last_response.should be_ok
    end

    it "should return no cache found string" do
      do_action
      last_response.body.should =~ /no cache found/i
    end

    describe "when file is found" do
      before(:each) do
        File.stub!(:exists?).and_return(true)
        File.stub!(:delete)
      end

      it "should delete the file" do
        File.should_receive(:delete).
          with("#{File.dirname(__FILE__)}/fixtures/avatars/users/000/012/345/original.jpg")
        do_action
      end

      it "should respond OK" do
        do_action
        last_response.should be_ok
      end

      it "should return a successful message" do
        do_action
        last_response.body.should =~ /successful/i
      end

      describe "when an error occurred during file deletion" do
        before(:each) do
          File.stub!(:delete).and_raise("avengers")
        end

        it "should return the status 422" do
          do_action
          last_response.status.should == 422
        end

        it "should return the error message" do
          do_action
          last_response.body.should =~ /avengers/
        end
      end
    end
  end
end

