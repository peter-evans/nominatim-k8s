workflow "Update Docker Hub Description" {
  resolves = ["Docker Hub Description"]
  on = "push"
}

action "Filter master branch" {
  uses = "actions/bin/filter@master"
  args = "branch master"
}

action "Docker Hub Description" {
  needs = ["Filter master branch"]
  uses = "peter-evans/dockerhub-description@v1.0.1"
  secrets = ["DOCKERHUB_USERNAME", "DOCKERHUB_PASSWORD", "DOCKERHUB_REPOSITORY"]
}
