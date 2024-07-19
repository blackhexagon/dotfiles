FROM archlinux:latest                                                                                             
                                                                                                                  
# Update the package database and install Ansible                                                                 
RUN pacman -Syu --noconfirm \                                                                                     
    && pacman -S git --noconfirm \                                                                            
    && pacman -S ansible --noconfirm \                                                                            
    && pacman -Scc --noconfirm                                                                                    
                                                                                                                  
# The entrypoint could be set to an init system, bash, or even ansible itself                                     
ENTRYPOINT ["/bin/bash"] 
