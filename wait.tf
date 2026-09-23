resource "time_sleep" "wait_for_security_group" {
  depends_on = [module.vpc]

  create_duration = "30s"
}
