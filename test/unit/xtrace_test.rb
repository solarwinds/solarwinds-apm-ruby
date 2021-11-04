# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe '::XTrace' do
  after do
    AppOpticsAPM::Context.clear
  end

  it 'valid?' do
    # Invalid X-Trace IDs
    _(AppOpticsAPM::XTrace.valid?("")).must_equal false
    _(AppOpticsAPM::XTrace.valid?(nil)).must_equal false
    _(AppOpticsAPM::XTrace.valid?("2B00000000000000000000000000000000000000000000000000000000")).must_equal false
    _(AppOpticsAPM::XTrace.valid?("2b")).must_equal false
    _(AppOpticsAPM::XTrace.valid?("29348209348")).must_equal false

    # Legacy X-Trace IDs are not valid anymore
    _(AppOpticsAPM::XTrace.valid?("1B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F")).must_equal false

    # Standard X-Trace IDs
    _(AppOpticsAPM::XTrace.valid?("2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00")).must_equal true
    _(AppOpticsAPM::XTrace.valid?("2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01")).must_equal true
    _(AppOpticsAPM::XTrace.valid?("2BADFDFB3DBA36323B2E0975925D0DAE12D10BA5946809504DC4B81FF601")).must_equal true

    # X-Trace IDs with lower-case alpha chars
    _(AppOpticsAPM::XTrace.valid?("2bf9861cb12e2a257247a8195654e56d30b2f4e2d4fce67c321ad5849500")).must_equal true
    _(AppOpticsAPM::XTrace.valid?("2b258b2c1d6914f3c6085cb72e7cc93e145b401d4356aa24ef7294b2d600")).must_equal true
  end

  it 'sampled?' do
    _(AppOpticsAPM::XTrace.sampled?("2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01")).must_equal true
    _(AppOpticsAPM::XTrace.sampled?("2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00")).must_equal false
  end

  it 'ok?' do
    _(AppOpticsAPM::XTrace.ok?("2B0000000000000000000000000000000000000000000000000000000000")).must_equal true
    _(AppOpticsAPM::XTrace.ok?("2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3468DA6F06EEFA01")).must_equal true
    _(AppOpticsAPM::XTrace.ok?("2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00")).must_equal true

    # Legacy X-Trace IDs are not ok anymore
    _(AppOpticsAPM::XTrace.ok?("1B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F")).must_equal false

    # too short
    _(AppOpticsAPM::XTrace.ok?("2BA462ADE6CFE479081764CC476AA983351DC51B1BCB3")).must_equal false
  end

  it 'set_sampled' do
    sampled = AppOpticsAPM::XTrace.set_sampled("2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00")
    _(sampled).must_equal("2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01")

    sampled_2 = AppOpticsAPM::XTrace.set_sampled(sampled)
    _(sampled_2).must_equal(sampled)
  end

  it 'unset_sampled' do
    unsampled = AppOpticsAPM::XTrace.unset_sampled("2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F01")
    _(unsampled).must_equal("2B7435A9FE510AE4533414D425DADF4E180D2B4E3649E60702469DB05F00")

    unsampled_2 = AppOpticsAPM::XTrace.unset_sampled(unsampled)
    _(unsampled_2).must_equal(unsampled)
  end

  it 'gets the task_id' do
    task_id = AppOpticsAPM::XTrace.task_id("2BF86B3D3342FCECAECE33C6411379BB171505DB6A136DFAEBDF74236200")
    _(task_id.is_a?(String)).must_equal true
    _(task_id).must_equal "F86B3D3342FCECAECE33C6411379BB171505DB6A"
    _(task_id.length).must_equal 40

    task_id = AppOpticsAPM::XTrace.task_id("2B77970F82332EE22FF04C249FCBA8F63E8AFA2C6730E209453259B2D601")
    _(task_id.is_a?(String)).must_equal true
    _(task_id).must_equal "77970F82332EE22FF04C249FCBA8F63E8AFA2C67"
    _(task_id.length).must_equal 40
  end

  it 'edge_id' do
    edge_id = AppOpticsAPM::XTrace.edge_id("2BF86B3D3342FCECAECE33C6411379BB171505DB6A136DFAEBDF74236200")
    _(edge_id.is_a?(String)).must_equal true
    _(edge_id).must_equal "136DFAEBDF742362"
    _(edge_id.length).must_equal 16

    edge_id = AppOpticsAPM::XTrace.edge_id("2B77970F82332EE22FF04C249FCBA8F63E8AFA2C6730E209453259B2D601")
    _(edge_id.is_a?(String)).must_equal true
    _(edge_id).must_equal "30E209453259B2D6"
    _(edge_id.length).must_equal 16
  end
end

