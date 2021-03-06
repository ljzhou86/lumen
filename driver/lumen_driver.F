!
!        Copyright (C) 2000-2016 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
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
integer function lumen_driver(np,pid,lnstr,iinf,iind,iod,icd,ijs,instr,inf,ind,od,com_dir,js)
 !
 ! LUMEN (derived from Yambo 4.1.2)
 !
 use drivers,       ONLY:l_HF_and_locXC,l_sc_run,l_eval_collisions,l_real_time,&
&                        l_optics,l_chi,l_em1s,l_ppa,l_cohsex,l_bss,l_bse,l_em1d,&
&                        l_gw0,l_elel_corr,l_life,l_acfdt,l_elphoton_corr,l_nl_optics
#if defined _SCALAPACK
 use drivers,       ONLY:l_slk_test
#endif
 use X_m,           ONLY:X_t
 use parallel_m,    ONLY:myid,ncpu
 use it_m,          ONLY:it_reset,infile
 use QP_m,          ONLY:QP_ng_Sx,QP_ng_SH
 use wave_func,     ONLY:wf_ng
 use electrons,     ONLY:levels,E_reset
#if defined _TIMING
 use timing_m,      ONLY:timing_overview,timing_deallocate,global_list
#endif
 use R_lattice,     ONLY:bz_samp,bz_samp_reset
 use frequency,     ONLY:w_samp
#if defined _ELPH
 use drivers,       ONLY:l_elph_Hamiltonian
#endif
 !
 implicit none
 type(levels) ::en,Xen,Ken
 type(bz_samp)::q,k,Xk
 ! 
 ! 4 response function & energies types: x s d p
 !
 type(X_t)    ::X(4) 
 type(w_samp) ::Xw(4)
 !
 integer,          intent(in)    :: lnstr,iind,iod,ijs,np,pid,icd
 integer,          intent(inout) :: iinf
 character(lnstr), intent(in)    :: instr
 character(iinf),  intent(in)    :: inf
 character(iind),  intent(in)    :: ind
 character(iod),   intent(in)    :: od
 character(ijs),   intent(in)    :: js
 character(icd),   intent(in)    :: com_dir
 !
 ! Local Variables
 !
 integer           ::i_err
 integer, external ::X_em1,INIT
 logical           ::l_pp_em1,l_dyn_em1
 !
 ! Presets
 !
 ncpu     =np
 myid     =pid
 infile   =inf
 !
 call SET_defaults(instr,ind,od,js,com_dir)
 call it_reset(1)
 !
 ! not resetted in INIT call
 !
 call bz_samp_reset(Xk)  
 call E_reset(Xen) 
 call E_reset(Ken) 
 !
 ! INPUT FILE PARSING
 !====================
 !
 lumen_driver=0
 !
 ! iinf=0 => No error message from driver.c 
 !
 iinf=0 
 iinf=INIT(en,q,k,X,Xw,instr,lnstr,.false.,.false.)
 !
 if (iinf/=0) return
 !
 ! PARALLEL and I/O Setup 
 !=======================
 !
 call PARALLEL_and_IO_Setup(en,k)
 !
 ! SETUPS ...
 !============
 !
 ! Basical 
 !
 call setup(en,Xen,Ken,k,Xk)
 !
 ! Update the default variables
 !
 i_err=INIT(en,q,k,X,Xw,instr,lnstr,.true.,.false.)
 !
 ! BZ sampling
 !
 call bz_samp_indexes(k,Xk,q) 
 !
 ! COLOUMB DRIVER
 !================
 !
 call col_driver(maxval((/wf_ng,QP_ng_Sx,QP_ng_SH/)),q)
 !
 ! reset the section numbering
 !
 call section('*','') 
 !
 ! RESPONSE FUNCTIONS QP CORRECTIONS (FROM INPUT FILE)
 !======================================================
 !
 call External_corrections(en,Xen,Ken,Xk,k,X)
 !
 ! OPTICS
 !========
 !
 if (l_optics.and.l_chi) call O_driver(Xen,Xk,q,Xw(3),X(3))
 !
 ! 
 ! INVERSE DIELECTRIC FUNCTIONS
 !===============================
 !
 ! Static
 !--------
 !
 if (l_em1s)       i_err=X_em1(Xen,Xk,q,X(2),Xw(2),.false.)
 !
 ! Plasmon Pole 
 !--------------
 !
 l_pp_em1=l_ppa.and.((l_em1d.and..not.l_life).or.(l_gw0.and.l_elel_corr).or.l_bse )
 !
 if (l_pp_em1)     i_err=X_em1(Xen,Xk,q,X(4),Xw(4),.false.)
 !
 ! Dynamical 
 !-----------
 !
 l_dyn_em1= (.not.l_ppa.and..not.l_cohsex.and..not.l_elphoton_corr).and. &
&           ((l_em1d.and..not.l_life).or.(l_gw0.and.l_elel_corr))
 !
 if (l_dyn_em1)    i_err=X_em1(Xen,Xk,q,X(3),Xw(3),.false.)
 !
 ! HARTREE-FOCK AND VXC
 !======================
 !
 if (l_HF_and_locXC.and..not.any((/l_sc_run,l_eval_collisions,l_real_time/))) call XCo_driver(en,k,Xk,q)
 !
 ! EXTENDED COLLISIONS (HF & COHSEX)
 !===================================
 !
 ! SELF-ENERGIES
 !===============
 !
 if (l_gw0.or.l_life) then
   !
   if (l_cohsex) then
     !
     ! COHSEX 
     !========
     !
     call QP_driver(X(2),Xen,Xk,en,k,q,Xw(2))
     !
   else if (l_ppa) then
     !
     ! PPA 
     !=====
     !
     call QP_driver(X(4),Xen,Xk,en,k,q,Xw(4))
     !
   else 
     !
     ! Real Axis 
     !============
     !
     call QP_driver(X(3),Xen,Xk,en,k,q,Xw(3))
     !
   endif
   !
 endif
 !
 ! BETHE-SALPETER
 !================
 !
 if ((l_optics.and.l_bse).or.l_bss) then
   if (l_ppa)      call K_driver(Xen,Ken,Xk,q,X(4),Xw(4))
   if (.not.l_ppa) call K_driver(Xen,Ken,Xk,q,X(2),Xw(2))
 endif
 !
 if (l_nl_optics) then
   !
   ! Non-linear optics
   !==================
   !
   call NL_driver(en,X(:2),k,q,Xw(:2))
   !
   !
 endif
 !
 !
#if defined _TIMING
 !
 ! Timing Overview
 !=================
 call section('*','Timing Overview')
 call timing_overview(LIST=global_list,MAIN_NAME="yambo")
#endif
 !
 ! GAME OVER :(
 !==============
 call section('X','Game Over & Game summary')
 !
 ! Update INIT defs
 !
 i_err=INIT(en,q,k,X,Xw,instr,lnstr,.false.,.true.)
 !
 ! Finalize
#if defined _TIMING
 call timing_deallocate( )
#endif
 call it_reset(-1)
 !
end function
