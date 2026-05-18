# LedgerV2::PhaseDGate — AutoMerge / AutoDeploy の実行可否を判定する。
#
# 目的:
# - Phase D の完了条件・停止条件をコードで説明可能にする
# - 実際の merge/deploy 実行は行わず、判定結果のみ返す
#
# 判定条件:
# - merge: auto_merge が有効 かつ draft PR が terminal(ci_passed)
# - deploy: merge 条件を満たし、かつ auto_deploy が有効
module LedgerV2
  module PhaseDGate
    GateResult = Struct.new(
      :merge_allowed,
      :deploy_allowed,
      :merge_block_reasons,
      :deploy_block_reasons,
      keyword_init: true
    )

    def self.call(artifact:)
      draft_pr = artifact.metadata_json.fetch("draft_pr", {})

      merge_block_reasons = base_block_reasons_for(draft_pr)
      merge_block_reasons << "auto_merge_disabled" unless Flags.enabled?(:auto_merge)

      deploy_block_reasons = merge_block_reasons.dup
      deploy_block_reasons << "auto_deploy_disabled" unless Flags.enabled?(:auto_deploy)

      GateResult.new(
        merge_allowed: merge_block_reasons.empty?,
        deploy_allowed: deploy_block_reasons.empty?,
        merge_block_reasons: merge_block_reasons,
        deploy_block_reasons: deploy_block_reasons
      )
    end

    class << self
      private

      def base_block_reasons_for(draft_pr)
        return ["draft_pr_missing"] if draft_pr.blank?

        reasons = []
        reasons << "draft_pr_number_missing" if draft_pr["number"].blank?
        reasons << "ci_not_terminal" unless draft_pr["ci_terminal"] == true
        reasons << "ci_not_passed" unless draft_pr["ci_terminal_reason"] == "ci_passed"
        reasons
      end
    end
  end
end
