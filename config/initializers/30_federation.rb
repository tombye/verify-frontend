require 'yaml_loader'
require 'idp_recommendations/idp_profiles_loader'
require 'idp_recommendations/segment_matcher'
require 'idp_recommendations/recommendations_engine'

Rails.application.config.after_initialize do
  # Federation localisation and display
  yaml_loader = YamlLoader.new
  RP_TRANSLATION_SERVICE = RpTranslationService.new
  repository_factory = Display::RepositoryFactory.new(I18n, yaml_loader)
  IDP_DISPLAY_REPOSITORY = repository_factory.create_idp_repository(CONFIG.idp_display_locales)
  RP_DISPLAY_REPOSITORY = repository_factory.create_rp_repository
  COUNTRY_DISPLAY_REPOSITORY = repository_factory.create_country_repository(CONFIG.country_display_locales)
  EIDAS_SCHEME_REPOSITORY = repository_factory.create_eidas_scheme_repository(CONFIG.eidas_schemes_directory)
  IDENTITY_PROVIDER_DISPLAY_DECORATOR = Display::IdentityProviderDisplayDecorator.new(
    IDP_DISPLAY_REPOSITORY,
    CONFIG.logo_directory,
  )

  EIDAS_SCHEME_DISPLAY_DECORATOR = Display::EidasSchemeDisplayDecorator.new(
    EIDAS_SCHEME_REPOSITORY,
    CONFIG.eidas_scheme_logos_directory
  )

  COUNTRY_DISPLAY_DECORATOR = Display::CountryDisplayDecorator.new(
    COUNTRY_DISPLAY_REPOSITORY,
    CONFIG.country_flags_directory
  )

  # Cycle Three display
  CYCLE_THREE_DISPLAY_REPOSITORY = repository_factory.create_cycle_three_repository(CONFIG.cycle_3_display_locales)
  CYCLE_THREE_FORMS = CycleThree::CycleThreeAttributeGenerator.new(YamlLoader.new, CYCLE_THREE_DISPLAY_REPOSITORY).attribute_classes_by_name(CONFIG.cycle_three_attributes_directory)
  FURTHER_INFORMATION_SERVICE = FurtherInformationService.new(POLICY_PROXY, CYCLE_THREE_FORMS)

  # RP/transactions config
  RP_CONFIG = YAML.load_file(CONFIG.rp_config)
  CONTINUE_ON_FAILED_REGISTRATION_RPS = RP_CONFIG.fetch('allow_continue_on_failed_registration', [])
  rps_name_and_homepage = RP_CONFIG['transaction_type']['display_name_and_homepage'] || []
  rps_name_only = RP_CONFIG['transaction_type']['display_name_only'] || []
  REDIRECT_TO_RP_LIST = RP_CONFIG['redirect_to_rp'] || []
  DATA_CORRELATOR = Display::Rp::DisplayDataCorrelator.new(RP_DISPLAY_REPOSITORY, rps_name_and_homepage.clone, rps_name_only.clone)
  TRANSACTION_TAXON_CORRELATOR = Display::Rp::TransactionTaxonCorrelator.new(RP_DISPLAY_REPOSITORY, rps_name_and_homepage.clone, rps_name_only.clone)

  SERVICE_LIST_DATA_CORRELATOR = Display::Rp::ServiceListDataCorrelator.new(RP_DISPLAY_REPOSITORY)

  # IDP Recommendations
  idp_rules_loader = IdpProfilesLoader.new(yaml_loader)
  idp_rules = idp_rules_loader.parse_config_files(CONFIG.rules_directory)

  # HUH-233 variant b, HUH-234 variant c
  idp_rules_variant_b = idp_rules_loader.parse_config_files(CONFIG.rules_variant_b_directory)
  idp_rules_variant_c = idp_rules_loader.parse_config_files(CONFIG.rules_variant_c_directory)

  # Segment Definitions
  segment_config = YAML.load_file(CONFIG.segment_definitions)
  segment_matcher = SegmentMatcher.new(segment_config)

  # HUH-233 variant b, HUH-234 variant c
  segment_config_variant_b = YAML.load_file(CONFIG.segment_definitions_variant_b)
  segment_config_variant_c = YAML.load_file(CONFIG.segment_definitions_variant_c)
  segment_matcher_variant_b = SegmentMatcher.new(segment_config_variant_b)
  segment_matcher_variant_c = SegmentMatcher.new(segment_config_variant_c)

  # Recommendation Engines
  transaction_grouper = TransactionGroups::TransactionGrouper.new(RP_CONFIG)
  IDP_RECOMMENDATION_ENGINE = RecommendationsEngine.new(idp_rules, segment_matcher, transaction_grouper)

  # HUH-233 variant b, HUH-234 variant c
  IDP_RECOMMENDATION_ENGINE_variant_b = RecommendationsEngine.new(idp_rules_variant_b, segment_matcher_variant_b, transaction_grouper)
  IDP_RECOMMENDATION_ENGINE_variant_c = RecommendationsEngine.new(idp_rules_variant_c, segment_matcher_variant_c, transaction_grouper)

  # ABC testing variation config
  # HUH-233 variant b, HUH-234 variant c
  ABC_VARIANTS_CONFIG = YAML.load_file(CONFIG.abc_variants_config)

  FEEDBACK_DISABLED = CONFIG.feedback_disabled

  # Feature flags
  IDP_FEATURE_FLAGS_CHECKER = IdpConfiguration::IdpFeatureFlagsLoader.new(YamlLoader.new)
                                 .load(CONFIG.rules_directory, %i[send_hints send_language_hint show_interstitial_question show_interstitial_question_loa1])
  SINGLE_IDP_FEATURE = CONFIG.single_idp_feature

  STUB_MODE = CONFIG.stub_mode
end
