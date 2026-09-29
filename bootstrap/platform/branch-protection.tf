resource "github_branch_protection" "main" {
  repository_id                   = "portfolio"
  pattern                         = "main"
  enforce_admins                  = true
  allows_force_pushes             = false
  allows_deletions                = false
  require_conversation_resolution = true

  required_status_checks {
    strict   = true
    contexts = ["validate (infra)", "validate (bootstrap/platform)", "Build portfolio"]
  }

  required_pull_request_reviews {
    require_code_owner_reviews      = false
    required_approving_review_count = 0
  }
}
