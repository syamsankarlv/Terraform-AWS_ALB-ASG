#========================================================
# Creating Target Groups For Application LoadBalancer
#========================================================

#-------------------------------------
#Target Group one
#-------------------------------------
resource "aws_lb_target_group" "tg-one" {
  name                          = "lb-tg-one"
  port                          = 80
  protocol                      = "HTTP"
  vpc_id                        = aws_vpc.vpc.id
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay          = 60
  stickiness {
    enabled         = false
    type            = "lb_cookie"
    cookie_duration = 60
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name    = "${var.project}-lb-tg-one"
    project = var.project
  }
}



#========================================================
# Application LoadBalancer
#========================================================

resource "aws_lb" "lb" {
  name                       = "lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.sgweb.id]
  subnets                    = [aws_subnet.Public-1.id, aws_subnet.Public-2.id, aws_subnet.Public-3.id]
  enable_deletion_protection = false
  depends_on                 = [aws_lb_target_group.tg-one]
  tags = {
    Name    = "${var.project}-lb"
    project = var.project
  }
}


output "alb-endpoint" {
  value = aws_lb.lb.dns_name
}

#========================================================
# Creating http listener of application loadbalancer
#========================================================

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"

  #-------------------------------------
  #default action of the target group.
  #-------------------------------------

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-one.arn
  }

  depends_on = [aws_lb.lb]
  tags = {
    Name    = "${var.project}-listener"
    project = var.project
  }
}

#========================================================
# forwarder with domain-hostname to target group
#========================================================

#-------------------------------------
#First forwarding rule
#-------------------------------------

resource "aws_lb_listener_rule" "rule-one" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-one.arn
  }

  condition {
    host_header {
      values = ["first-host-name.example.com"]
      
    }
    
  }
}
