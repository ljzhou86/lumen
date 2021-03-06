!
! Copyright (C) 2000-2013 A. Marini, C. Attaccalite and the YAMBO team 
!              http://www.yambo-code.org
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
subroutine NL_start_and_restart(E,k,X)
 !
 ! This subroutine initialize some variables and 
 ! restart from a previous NL calculation
 !
 ! [1] Initialize the Vbands and potentials
 ! [2] Build Ho
 ! [3] RESTART from a previous run
 ! [4] Initialize the bare Hartree and XC
 ! [5] Initialize the fields
 !
 use pars,           ONLY:cZERO,rZERO,cONE,SP,LP
 use com,            ONLY:msg
 use electrons,      ONLY:levels,n_sp_pol
 use R_lattice,      ONLY:bz_samp,k_map
 use X_m,            ONLY:X_t
 use X_m,            ONLY:X_t 
 use xc_functionals, ONLY:V_xc,XC_potential_driver
 use QP_m,           ONLY:QP_nk
 use memory_m,       ONLY:mem_est
 use global_XC,      ONLY:WF_kind,WF_xc_functional
 use fields,         ONLY:A_vecpot,A_ext,A_vecpot_reset
 use parallel_m,     ONLY:master_cpu
 use nl_optics,      ONLY:Correlation,IPA,E_full,full_rho,V_bands,TDDFT,n_runs_todo,NL_LRC_alpha,Alpha_ED,NL_bands,  &
&                         V_xc_0,NL_initial_P,l_use_DIPOLES,n_runs,runs_done,JGM,E_xc_0,I_relax,l_use_DIPOLES,&
&                         NL_P,E_full,E_bare,Hk,rho_n,full_rho,rho_reference,V_hartree_ne,V_xc_ne,VAL_BANDS
 use IO_m,           ONLY:OP_RD_CL,io_control,NONE,file_is_present,VERIFY
 use parallel_m,     ONLY:PAR_IND_runs,PP_redux_wait
 use stderr,         ONLY:intc
 use IO_m,           ONLY:IO_and_Messaging_switch
 !
 implicit none
 !
 type(levels)      :: E
 type(bz_samp)     :: k
 type(X_t)         :: X
 !
 ! Working space
 !
 integer :: i1,ib,i_f
 integer :: ID,io_NonLinear
 integer, external::io_NL
 !
 !
 ! Initialize the Gf and potentials
 !==================================
 if(Correlation/=IPA) then
   !  
   rho_reference     =rZERO
   if(allocated(full_rho)) full_rho=rZERO
   V_xc_ne =rZERO
   V_hartree_ne      =rZERO
   !
 endif
 ! 
 V_bands           =cZERO
 Hk                =cZERO
 I_relax           =cZERO
 !
 forall(i1=1:E%nbf) V_bands(i1,i1,:,:)=cONE
 !
 if(Correlation/=IPA) then
   !  
   call NL_build_valence_bands(E,V_bands,VAL_BANDS,1)
   call el_density_vbands(E,k,full_rho,VAL_BANDS)
   !
   call NL_build_valence_bands(E,V_bands,VAL_BANDS,NL_bands(1))
   call el_density_vbands(E,k,rho_reference,VAL_BANDS)
   !
   rho_n=full_rho
   !
 endif
 !
 ! Fields
 !=====================
 call A_vecpot_reset(A_vecpot)
 call A_vecpot_reset(A_ext)
 !
 if(Correlation==TDDFT) then
   !
   ! Calculate V_xc
   !
   call XC_potential_driver(E,k,WF_KIND,WF_xc_functional,1,MUTE="-report -log -io_in -io_out",unMUTE=master_cpu)
   call IO_and_Messaging_switch("+report +log +io_in +io_out")
   V_xc_0=V_xc
   !       
 endif
 !
 if(Correlation==JGM) then
   NL_P=cZERO
   call EXC_macroscopic_JGM(E,NL_P,rho_n,E_xc_0,V_xc_0)
   call msg('sr',' JGM initial alpha :',NL_LRC_alpha)
 endif
 !
 ! Build initial energies
 !=======================
 if(associated(E%Eo)) then
   E_bare=E%Eo(:NL_bands(2),:,:)
 else
   E_bare=E%E(:NL_bands(2),:,:)
 endif
 !
 E_full=E_bare
 !
 ! Apply QP Corrections
 ! ====================
 do ib=NL_bands(1),NL_bands(2)
   E_full(ib,1:QP_nk,1:n_sp_pol)=E_full(ib,1:QP_nk,1:n_sp_pol) &
&                                 -E_bare(ib,1:QP_nk,1:n_sp_pol)+E%E(ib,1:QP_nk,1:n_sp_pol)
 enddo
 !
 do ib=1,NL_bands(1)-1
   E_full(ib,1:QP_nk,1:n_sp_pol)=E_full(ib,1:QP_nk,1:n_sp_pol) &
& -E_bare(NL_bands(1),1:QP_nk,1:n_sp_pol)+E%E(NL_bands(1),1:QP_nk,1:n_sp_pol)
 enddo
 !
 ! Evaluate Initial Polarization
 ! ====================================
 !
 if(.not.l_use_DIPOLES) then
   if(.not.allocated(k_map%k_map_dir)) call k_map_nearest_by_dir(k,k_map)
   if(.not.associated(k%k_table))      call k_build_up_BZ_tables(k)
   call POLARIZATION_output(E,k,X)
 endif
 !
 if(l_use_DIPOLES) then
   call DIP_polarization(E,k,V_bands,NL_initial_P)
 else
   ! This subroutine update also the Sm1_plus,Sm1_minus and All_S_det matrices
   call Berry_Polarization_NEQ(E,k,V_bands,NL_initial_P)
   !
 endif
 !
 call msg('r ',' Initial Polarization :',real(NL_initial_P))
 !
 ! Restart
 ! ====================================
 allocate(runs_done(n_runs))
 call mem_est("runs_done",(/size(runs_done)/),(/LP/))
 !
 runs_done=.false.
 !
 if(master_cpu) then
   !      
   call io_control(ACTION=OP_RD_CL,COM=NONE,SEC=(/1/),MODE=VERIFY,ID=ID)
   io_Nonlinear=io_NL(ID)
   !
   if(io_Nonlinear==0) then
     do i_f=1,n_runs
        if(file_is_present('Nonlinear_fragment_'//intc(i_f))) runs_done(i_f)=.true.
     enddo                                                                    
    endif
    !
 endif
 !
 call PP_redux_wait(runs_done,imode=3)
 !
 n_runs_todo=n_runs-count(runs_done)
 if(n_runs_todo/=n_runs) call msg('s','RESTART, remaining runs: ',n_runs_todo)
 !
end subroutine NL_start_and_restart

