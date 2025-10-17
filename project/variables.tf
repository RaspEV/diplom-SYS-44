variable "flow" {
  type    = string
  default = "net"
}

variable "cloud_id" {
  type    = string
  default = "b1gci3asj6absh20om3e"
}
variable "folder_id" {
  type    = string
  default = "b1gl1kemunqbi3b6ca7h"
}

variable "cfg" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 2
    core_fraction = 20
    storage = 10
  }
}
