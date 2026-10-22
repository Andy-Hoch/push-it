class Api::V1::ProfilesController < Api::BaseController
  allow_anonymous_access only: :create
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render_error :rate_limited, I18n.t("sessions.rate_limited"), status: :too_many_requests }

  def show
    render_profile
  end

  def create
    Current.profile = Profile.create_guest!(params[:name])
    render_profile status: :created
  end

  def update
    current_profile.update!(params.expect(profile: [ :name ]))
    render_profile
  end

  def destroy
    current_profile.forget!
    head :no_content
  end

  private
    def render_profile(status: :ok)
      @profile = current_profile
      @finished_games = @profile.finished_games.includes(:winner, seats: :profile).limit(20)
      render :show, status: status
    end
end
