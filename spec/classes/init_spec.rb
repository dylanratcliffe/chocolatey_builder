require 'spec_helper'
describe 'chocolatey_builder' do
  context 'with default values for all parameters' do
    it { should contain_class('chocolatey_builder') }
  end
end
