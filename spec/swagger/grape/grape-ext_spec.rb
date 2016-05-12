require 'spec_helper'

require_relative '../../fixtures/grape/applications_api'

describe Grape::DSL::Configuration do
  context 'with no overridden default values' do
    let(:route) { ApplicationsAPI.routes.first }
    subject { Swagger::Grape::RouteSettings.new(route) }

    fit 'should inspect extended parameters for Grape' do
      expect(subject.headers).to eq({ 'Authorization' => { description: "A valid user session token, in the format 'Bearer TOKEN'", required: true } })
      expect(subject.api_name).to eq 'get_applications'
      expect(subject.detail).to eq 'This API does this and that and more'
      expect(subject.scopes).to eq ['application:read']
      expect(subject.tags).to eq ['applications']
      expect(subject.deprecated).to be_truthy
      expect(subject.hidden).to be_falsey
      expect(subject.response).not_to be_nil
      expect(subject.response[:entity]).to eq ApplicationEntity
      expect(subject.response[:root]).to eq 'applications'
      expect(subject.response[:headers]).to eq({ 'X-Request-Id' => { description: 'Unique id of the API request', type: 'string' },
                                                 'X-Runtime' => { description: 'Time spent processing the API request in ms', type: 'string' },
                                                 'X-Rate-Limit-Limit' => { description: 'The number of allowed requests in the current period', type: 'integer' },
                                                 'X-Rate-Limit-Remaining' => { description: 'The number of remaining requests in the current period', type: 'integer' },
                                                 'X-Rate-Limit-Reset' => { description: 'The number of seconds left in the current period', type: 'integer' } })
      expect(subject.errors).to eq({ '300' => { entity: ErrorRedirectEntity, description: 'You will be redirected' },
                                     '404' => { entity: ErrorNotFoundEntity, description: 'The document is nowhere to be found' },
                                     '501' => { entity: ErrorBoomEntity, description: 'Shit happens' },
                                     '418' => { entity: ErrorBoomEntity, description: 'Yes, I am a teapot' } })
    end
  end
end
