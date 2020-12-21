terraform {
  backend "s3" {
    region = "us-east-1"
    bucket = "mfdb-tf-remote-state"
    key    = "mfdb-tf-remote-state/development/state.tfstate"
    #encrypt = true    #AES-256 encryption
  }
}
