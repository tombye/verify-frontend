class SelectPhoneVariantController < ApplicationController
  def index
    @form = SelectPhoneForm.new({})
    render 'select_phone/index'
  end

  def select_phone
    @form = SelectPhoneForm.new(params['select_phone_form'] || {})
    if @form.valid?
      report_to_analytics('Phone Next')
      selected_answer_store.store_selected_answers('phone', @form.selected_answers)
      idps_available = IDP_ELIGIBILITY_CHECKER_B.any?(selected_evidence, current_identity_providers)
      redirect_to idps_available ? choose_a_certified_company_path : no_mobile_phone_path
    else
      flash.now[:errors] = @form.errors.full_messages.join(', ')
      render 'select_phone/index'
    end
  end

  def no_mobile_phone
    @other_ways_description = current_transaction.other_ways_description
    @other_ways_text = current_transaction.other_ways_text
    render 'select_phone/no_mobile_phone'
  end
end
