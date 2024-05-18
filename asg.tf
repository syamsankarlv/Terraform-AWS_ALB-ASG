#========================================================
# Launch Configurations
#========================================================

resource "aws_launch_configuration" "launch-one" {
  image_id        = var.image_id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.sgweb.id]
  user_data       = file("launch-conf.sh")
  lifecycle {
    create_before_destroy = true
  }
}

#========================================================
# ASG Creations
#========================================================

#-------------------------------------
#First ASG with Launch conf one
#-------------------------------------

resource "aws_autoscaling_group" "asg-one" {
  launch_configuration = aws_launch_configuration.launch-one.id
  health_check_type    = "EC2"
  min_size             = var.asg_count
  max_size             = var.asg_count
  desired_capacity     = var.asg_count
  vpc_zone_identifier  = [aws_subnet.Public-1.id, aws_subnet.Public-2.id, aws_subnet.Public-3.id]
  target_group_arns    = [aws_lb_target_group.tg-one.arn]
  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "asg-one"
  }
  lifecycle {
    create_before_destroy = true
  }
}