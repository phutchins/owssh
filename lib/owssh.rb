#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'pp'
require 'command_line_reporter'

class Owssh
  include CommandLineReporter

  def get_stacks
    my_stacks = {}
    stacks_json = JSON.parse(`aws opsworks describe-stacks`)

    stacks_json['Stacks'].each do |stack|
      if $debug then puts "Stack Name: #{stack['Name'].gsub(' ','_').downcase}     Stack ID: #{stack['StackId']}" end
      stack_name = stack['Name'].gsub(' ','_').downcase
      my_stacks[stack_name.to_s] = stack['StackId']
    end
    my_stacks
  end

  def get_instances(id)
    my_instances = {}
    instances_json = JSON.parse(`aws opsworks describe-instances --stack-id #{id}`)
    instances_json['Instances'].each do |instance|
      pub_ip = instance['ElasticIp'] || instance['PublicIp'] || "DOWN"
      priv_ip = instance['PrivateIp'] || "N/A"
      type = instance['Hostname'].split("-").first
      my_instances[instance['Hostname'].to_s] = { "PUB_IP" => pub_ip.to_s, "PRIV_IP" => priv_ip.to_s, "TYPE" => type }
    end
    my_instances
  end

  def print_instances(instances)
    table(:border => true) do
      row do
        column('Hostname', :width => 20)
        column('Public IP', :width => 15, :align => 'right')
        column('Private IP', :width => 15, :align => 'right')
        column('Type', :width => 12)
      end
      instances.each do |instance_name, data|
        row do
          column(instance_name)
          column(data['PUB_IP'])
          column(data['PRIV_IP'])
          column(data['TYPE'])
        end
      end
    end
  end

  def print_stacks(stacks)
    table(:border => true) do
      row do
        column('Stack Name', :width => 20)
        column('Stack ID', :width => 40, :align => 'right')
      end
      stacks.each do |stack_name, id|
        row do
          column(stack_name)
          column(id)
        end
      end
    end
  end

  def owssh
    # Export environment variables for AWS CLI here
    $debug = false
    $ssh_key_file = "~/.ssh/id_rsa_dev"
    $owssh_config = "~/.owssh_conf"

    if ARGV.empty?
      puts "Usage:"
      puts "owssh list - List all environments"
      puts "owssh describe - Show details of hosts in all stacks"
      puts "owssh describe [Stack Name] - Show details of a specific stack"
      puts "owssh [Stack Name] [Hostname] - SSH to a host in a stack"
      puts "owssh [Stack Name] [Hostname] [Command]- SSH to a host in a stack and run a command"
      exit
    end

    $stacks = {}
    $instances = {}

    $stacks = get_stacks

    if ARGV[0] == "list" then
      puts "Getting list of stacks..."
      print_stacks($stacks)
      exit
    elsif ARGV[0] == "describe" && ARGV[1].nil? then
      $stacks.each do |stack_name, id|
        puts "Getting data for Stack: #{stack_name}"
        $instances = get_instances(id)
        print_instances($instances)
      end
      exit
    elsif ARGV[0] == "describe" && !ARGV[1].nil? then
      stack_name = ARGV[1]
      if $stacks.has_key?(ARGV[1].downcase.to_s) then
        if $debug then puts "Stack ID: #{$stacks[stack_name]}" end
        puts "Getting data for Stack: #{stack_name}"
        $instances = get_instances($stacks[stack_name])
        print_instances($instances)
      elsif
        puts "Unable to find stack named '#{ARGV[1]}'"
        exit
      end
    elsif $stacks.has_key?(ARGV[0].downcase.to_s) then
      if ARGV[1].nil? then
        puts "Please enter an instance name. I.E. rails-app3"
        exit
      end
      stack_arg = ARGV[0].downcase
      instances_json = JSON.parse(`aws opsworks describe-instances --stack-id #{$stacks[stack_arg]}`)
      instances_json['Instances'].each do |instance|
        $instances["#{instance["Hostname"]}"] = instance["PublicIp"]
      end
      if $instances.has_key?(ARGV[1]) then
        if ARGV[2].nil? then
          puts "Opening connection to #{ARGV[1]}..."
          exec("ssh -i ~/.ssh/id_rsa_dev ubuntu@#{$instances[ARGV[1].to_s]}")
        else
          puts "Running comand #{ARGV[2]} on host #{ARGV[1]}..."
          exec("ssh -i ~/.ssh/id_rsa_dev ubuntu@#{$instances[ARGV[1].to_s]} '#{ARGV[2]}'")
        end
      else
        puts "Instance with name '#{ARGV[1]}' not found"
        exit
      end
    else
      puts "I don't quite understand what you're asking me to do..."
      puts " Try running owssh with no arguments for help!"
      exit
    end
  end
end
