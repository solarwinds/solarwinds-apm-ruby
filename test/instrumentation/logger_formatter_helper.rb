

describe "include traceId in message " do

  before do
    AppopticsAPM::Context.clear
    @log_traceId = AppOpticsAPM::Config[:log_traceId]
  end

  after do
    AppopticsAPM::Context.clear
    AppOpticsAPM::Config[:log_traceId] = @log_traceId
  end

  describe "Formatted msg is a String " do

    it 'adds a traceId when :always' do
      AppOpticsAPM::Config[:log_traceId] = :always

      _(msg).must_match /Message/
      _(msg).must_match /ao(=>{:|\.){1}traceId=(>\"){0,1}0000000000000000000000000000000000000000-0/
      _(msg).wont_match /traceId.*traceId/
    end

    it 'adds a traceId when :traced' do
      AppOpticsAPM::Config[:log_traceId] = :traced
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA00')

      _(msg).must_match /Message/
      _(msg).must_match /ao(=>{:|\.){1}traceId=(>\"){0,1}A462ADE6CFE479081764CC476AA983351DC51B1B-0/
      _(msg).wont_match /traceId.*traceId/
    end

    it 'Does NOT add a traceId when :traced and no context' do
      AppOpticsAPM::Config[:log_traceId] = :traced

      _(msg).must_match /Message/
      _(msg).wont_match /traceId/
    end

    it 'adds a traceId when :sampled' do
      AppOpticsAPM::Config[:log_traceId] = :sampled
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01')

      _(msg).must_match /Message/
      _(msg).must_match /ao(=>{:|\.){1}traceId=(>\"){0,1}A462ADE6CFE479081764CC476AA983351DC51B1B-1/
      _(msg).wont_match /traceId.*traceId/
    end

    it 'Does NOT add a traceId when :sampled and not sampled' do
      AppOpticsAPM::Config[:log_traceId] = :sampled
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA00')

      _(msg).must_match /Message/
      _(msg).wont_match /traceId/
    end

    it 'Does NOT add a traceId when :never' do
      AppOpticsAPM::Config[:log_traceId] = :never
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01')

      _(msg).must_match /Message/
      _(msg).wont_match /traceId/
    end

    it 'Does NOT add a traceId when no config' do
      AppOpticsAPM::Config[:log_traceId] = nil
      AppOpticsAPM::Context.fromString('2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01')

      _(msg).must_match /Message/
      _(msg).wont_match /traceId/
    end

  end

  describe "Formatted msg is NOT a String" do
    it 'adds a ao.traceId when it is an Exception' do
      AppOpticsAPM::Config[:log_traceId] = :always

      _(exc_message).must_match /StandardError/
      _(exc_message).must_match /ao.traceId=0000000000000000000000000000000000000000-0/
      _(exc_message).wont_match /traceId.*traceId/
    end
  end
end