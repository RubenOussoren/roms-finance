class RemoveSynthFromEnums < ActiveRecord::Migration[7.2]
  def up
    DataEnrichment.where(source: "synth").update_all(source: "ai")
    ProviderMerchant.where(source: "synth").update_all(source: "ai")
  end

  def down
    # No-op: cannot determine which records were originally "synth"
  end
end
