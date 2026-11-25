class SpectrumPreferencesController < ApplicationController
  def update
    ids = params[:spectrum_ids].presence
    ids = params.expect(spectrum_ids: []) if ids
    set_selected_spectrum_ids ids
    session[:multiple_spectrums] = params[:multiple] == true
    head :no_content
  end
end
