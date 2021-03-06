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
subroutine bz_samp_indexes(k,Xk,q)
 !
 ! ikbz=(ik,is) --<--:--<-- okbz=(ok,os) = (IK-Q)
 !                   :
 !                  /:\ iqbz=(iq,is)
 !                   :
 !
 ! iq_is = ik_is-ok_os-Go
 !
 ! qindx_X(iq,ikbz,1)=okbz
 ! qindx_X(iq,ikbz,2)=iGo
 !
 ! qindx_B(ikbz,okbz,1)=iqbz
 ! qindx_B(ikbz,okbz,2)=iGo
 !
 ! qindx_S(ik,iqbz,1)=okbz
 ! qindx_S(ik,iqbz,2)=iGo
 !
 use pars,           ONLY:SP,lchlen,IP
 use drivers,        ONLY:l_bse,l_elel_scatt
 use memory_m,       ONLY:mem_est
 use stderr,         ONLY:gen_fmt
 use com,            ONLY:msg,error,warning
 use parallel_m,     ONLY:PP_redux_wait
 use LIVE_t,         ONLY:live_timing
 use matrix_operate, ONLY:m3inv,m3det
 use vec_operate,    ONLY:v_is_zero,c2a
 use R_lattice,      ONLY:d3q_factor,RL_vol,nqibz,nqbz,qp_states_k,&
&                         qindx_X,qindx_B,qindx_S,qindx_C,&
&                         bse_scattering,qindx_alloc,Xk_grid_is_uniform,&
&                         k_grid,k_grid_b,q_pt,k_pt,bz_samp,q_norm,q0_def_norm,&
&                         q_sstar,coll_scattering,q_source
 use IO_m,           ONLY:io_control,OP_RD_CL,OP_WR_CL,VERIFY,REP
 use parser_m,       ONLY:parser
#if defined _ELPH
 use ELPH,           ONLY:elph_use_q_grid
#endif
 !
 implicit none
 type(bz_samp)::k,Xk,q
 !
 !Work Space
 !
 integer, external :: G_index
 !
 character(lchlen) :: string
 integer :: io_db,io_err,io_QINDX
 integer :: i1,i2,i3,i4,iv1(3),iqibz,iqbz,ikibz,ikbz,ikbz_p,iqs,iks
 real(SP):: v1(3),k_b_m1(3,3),local_zero(3)
 logical :: connected_grids,user_defined_qpts,gamma_point_only
#if defined _ELPH
 logical :: bse_setup_scatt
#endif
 integer, allocatable :: q_map(:,:,:),q_iptbz(:,:)
 !
 call section('*','Transferred momenta grid')
 !
 user_defined_qpts=.false.
 gamma_point_only=.false.
 !
 if (.not.bse_scattering ) bse_scattering =l_bse
 if (.not.coll_scattering) coll_scattering=l_elel_scatt
#if defined _ELPH
 call parser('BSEscatt',bse_setup_scatt)
 if (.not.bse_scattering ) bse_scattering =elph_use_q_grid.or.bse_setup_scatt.or.&
&                                          trim(q_source)=="Electron-Phonon databases"
#endif
 !
 q%description='q'
 !
 call io_control(ACTION=OP_RD_CL,COM=REP,SEC=(/1,2,3/),MODE=VERIFY,ID=io_db)
 io_err=io_QINDX(Xk,q,io_db)
 if (io_err==0) then
   call k_expand(q)
   call Q_report('iku')
   call Q_report('cc ')
   call q_shadows(.false.)
   return
 endif
 !
 ! First I map the Xk grid in a simple cubic Net
 !
 call k_ibz2bz(Xk,'a',.false.)  
 !
 allocate(q_map(k_grid(1),k_grid(2),k_grid(3)),q_iptbz(Xk%nbz,3))
 !
 ! k_b_m1=transpose(k_grid_b) in rlu
 !
 ! k_grid_b is in cc !
 !
 call c2a(v_in=k_grid_b(1,:),v_out=k_b_m1(:,1),mode='kc2a')
 call c2a(v_in=k_grid_b(2,:),v_out=k_b_m1(:,2),mode='kc2a')
 call c2a(v_in=k_grid_b(3,:),v_out=k_b_m1(:,3),mode='kc2a')
 !
 ! q_iptbz(i,:) = Xk%ptbz(1,:) - Vo  in units of k_grid_b
 ! q_map gives the index of q_iptbz given the components along k_grid_b
 !
 ! As first step I define the map with respect to Q defined as difference
 ! of K-pts
 !
 if (abs(m3det(k_b_m1))>1.E-7) then
   !
   call m3inv(M=k_b_m1)
   !
   call define_q_map( Xk%ptbz(:,:), Xk%ptbz(1,:))
   !
   ! THE GRID IS UNIFORM IF ALL THE Q_MAP IS FILLED
   !
   Xk_grid_is_uniform=all(q_map/=0)
   !
 else
   Xk_grid_is_uniform=.false.
 endif
 !
 if (Xk_grid_is_uniform) then
   !
   q%nbz=Xk%nbz
   !
   ! q_ptbz in iku for k_reduce
   !
   allocate(q%ptbz(q%nbz,3))
   do i1=1,q%nbz
     !
     v1=Xk%ptbz(i1,:)-Xk%ptbz(1,:)
     !
     call c2a(v_in= v1,v_out=q%ptbz(i1,:),mode='ka2i')
     !
   enddo
   if (.not.allocated(q_pt)) then
     call k_reduce(q,.TRUE.)
     deallocate(q%ptbz)
   else
     q%nibz=nqibz
     allocate(q%pt(q%nibz,3))
     q%pt=q_pt(:q%nibz,:)
     call msg('rsn','[RL indx] Q-grid:'//trim(q_source))
     user_defined_qpts=.true.
   endif
   !
   ! q_ptbz in rlu for qindx_*.
   ! At difference with the Q list used in evaluating the map before
   ! here I need to recalculate the map so that it correctly points
   ! to the q%ptbz obtaine trought q_expand
   !
   call k_expand(q)
   call q_shadows(.false.)
   call k_ibz2bz(q,'a',.false.)
   nqbz =q%nbz
   nqibz=q%nibz
   call Q_report('iku')
   call Q_report('cc ')
   !
   ! When using USER defined Q-points q%nbz may be different from Xk%nbz
   ! if the given list is not correct.
   ! In this case I switch to the Gamma only support
   !
   if (q%nbz/=Xk%nbz) then
     call msg('rsn','[RL indx] Q BZ pts are /= from X grid BS pts. Gamma point only.')
     call q_shadows(.true.)
     !
     ! when imposing the G point with a uniform X grid I get
     ! segmentation fault in the BSE. 
     !
     Xk_grid_is_uniform=.false.
     bse_scattering=.false.
     gamma_point_only=.true.
   else
     call define_q_map(q%ptbz(:,:),(/0._SP,0._SP,0._SP/))
   endif
   !
 else
   !
   call msg('nrsn','[RL indx] X grid is not uniform.  Gamma point only.')
   call q_shadows(.true.)
   gamma_point_only=.true.
   bse_scattering=.false.
   !
 endif
 !
 ! Allocate
 !
 call qindx_alloc()
 !
 ! Gamma point only
 !
 if (gamma_point_only) then
   forall(i1=1:Xk%nbz) qindx_X(1,i1,1)=i1
   forall(i1=1:Xk%nbz) qindx_X(1,i1,2)=1
   goto 1
 endif
 !
 string=':: Indices: polarization function'
 if ( bse_scattering) string=trim(string)//' + BSE'
 if (coll_scattering) string=trim(string)//' + COLL'
 call msg('nr',trim(string))
 !
 qindx_X=0
 qindx_S=0
 if ( bse_scattering) qindx_B=0
 if (coll_scattering) qindx_C=0
 !
 ! X indexes
 !
 ! qindx_X(iq,ikbz,1)=okbz
 ! qindx_X(iq,ikbz,2)=iGo
 !
 ! qindx_B(ikbz,okbz,1)=iqbz
 ! qindx_B(ikbz,okbz,2)=iGo
 !
 call live_timing('X indexes',Xk%nbz)
 !
 do ikbz=1,Xk%nbz
   !
   do ikbz_p=1,Xk%nbz
     v1=matmul(k_b_m1,Xk%ptbz(ikbz,:)-Xk%ptbz(ikbz_p,:)) ! K-K_p= Q + Go
     iv1=nint(v1)
     call k_grid_shift(iv1)
     iqbz =q_map(iv1(1),iv1(2),iv1(3))
     iqibz=q%sstar(iqbz,1)
     iqs  =q%sstar(iqbz,2)
     if (iqs/=1.and..not.bse_scattering) cycle
     if (iqs==1) qindx_X(iqibz,ikbz,1)=ikbz_p
     if (bse_scattering) qindx_B(ikbz,ikbz_p,1)=iqbz
     v1=Xk%ptbz(ikbz,:)-Xk%ptbz(ikbz_p,:)-q%ptbz(iqbz,:)
     call c2a(v_in=v1,mode='ka2i')
     !
     if (iqs==1)         qindx_X(iqibz,ikbz  ,2)=G_index(v1)
     if (bse_scattering) qindx_B(ikbz ,ikbz_p,2)=G_index(v1)
     !
   enddo
   !
   call live_timing(steps=1)
   !
 enddo
 call live_timing()
 !
 if (any(qindx_X==0)) call error('Error in Q-grid search [qindx_X]')
 !
 if(coll_scattering) then
   call msg('rn',':: Indices: Scattering and Self-Energy')
   call live_timing('SSE indexes',k%nbz)
 else
   call msg('rn',':: Indices: Self-Energy')
   call live_timing('SE indexes',qp_states_k(2)-qp_states_k(1)+1)
 endif
 !
 call k_ibz2bz(k,'a',.false.)
 !
 connected_grids=.true.
 local_zero=1.E-4_SP
 !
 ! qindx_S(ik,iqbz,1)=okbz
 ! qindx_S(ik,iqbz,2)=iGo
 !
 ! qindx_C(ikbz,iqbz,1)=okbz
 ! qindx_C(ikbz,iqbz,2)=iGo
 !
 do ikbz=1,Xk%nbz
   !
   ikibz=k%sstar(ikbz,1)
   iks  =k%sstar(ikbz,2)
   !
   if (iks/=1.and..not.coll_scattering) cycle
   !
   do ikbz_p=1,k%nbz
     !
     v1=matmul(k_b_m1,k%ptbz(ikbz,:)-k%ptbz(ikbz_p,:))
     iv1=nint(v1)
     !
     if (.not.v_is_zero(v1-real(iv1,SP),zero_=local_zero)) connected_grids=.false.
     if (.not.v_is_zero(v1-real(iv1,SP),zero_=local_zero)) cycle
     !
     call k_grid_shift(iv1)
     iqbz=q_map(iv1(1),iv1(2),iv1(3))
     !
     if (iks==1) qindx_S(ikibz,iqbz,1)=ikbz_p
     if (coll_scattering) qindx_C(ikbz,iqbz,1)=ikbz_p
     v1=k%ptbz(ikbz,:)-k%ptbz(ikbz_p,:)-q%ptbz(iqbz,:)
     call c2a(v_in=v1,mode='ka2i')
     if (iks==1) qindx_S(ikibz,iqbz,2)=G_index(v1)
     if (coll_scattering) qindx_C(ikbz,iqbz,2)=G_index(v1)
   enddo
   !
   if (any(qindx_S(ikibz,:,:)==0)) call error(' Null transition detected [qindx_S]')
   !
   call live_timing(steps=1)
   !
 enddo
 !
 call live_timing()
 !
 ! For some reason I have seen CPU's loading the DB while/before it is actually written.
 ! This is avoided here by using the PP_redux_wait call.
 !
 call PP_redux_wait()
 !
 if (.not.connected_grids) call msg('rsn','[RL indx] X & Total k-grids are not connected')
 !
1 call io_control(ACTION=OP_WR_CL,COM=REP,SEC=(/1,2,3/),ID=io_db)
 io_err=io_QINDX(Xk,q,io_db)
 !
 !CLEAN
 !
 call k_ibz2bz(Xk,'d',.false.)
 deallocate(q_map,q_iptbz)
 if (Xk_grid_is_uniform) deallocate(q%ptbz)
 call PP_redux_wait()
 !
 contains 
   !
   subroutine Q_report(kind)
     character(3)     ::kind
     character(lchlen)::ch(4)
     real(SP)         ::q_cc(3)
     if(trim(kind)=='iku') then
       call msg('nr','IBZ Q-points :',q%nibz)
       call msg('rn','BZ  Q-points :',q%nbz)
     endif
     if(trim(kind)=='cc') call msg('r',' ')
     d3q_factor=RL_vol/real(q%nbz)
     do i1=1,q%nibz
       if(trim(kind)=='cc') call c2a(v_in=q%pt(i1,:),v_out=q_cc,mode='ki2c')
       ch(2)=gen_fmt(r_v=q%pt(i1,:))
       ch(3)=gen_fmt(r_v=(/q%weights(i1)/))
       write (ch(1),'(7a)') '(a,i5.5,a,3(',trim(ch(2)),',1x),a,',trim(ch(3)),',1x)'
       if(trim(kind)=='cc')  write (ch(2),trim(ch(1)))   'Q [',i1,'] :',q_cc(:),'(cc ) * weight ',q%weights(i1)
       if(trim(kind)=='iku') write (ch(2),trim(ch(1)))   'Q [',i1,'] :',q%pt(i1,:),'(iku) * weight ',q%weights(i1)
       call msg('r',trim(ch(2)))
     enddo
   end subroutine
   !
   subroutine k_grid_shift(v)
     implicit none
     integer  :: v(3),u(3),i1
     do i1=1,3
       if (v(i1)>=0) u(i1)=mod(v(i1)+1,k_grid(i1))
       if (v(i1)>=0.and.u(i1)==0) u(i1)=k_grid(i1)
       if (v(i1)<0) u(i1)=mod(v(i1),k_grid(i1))
       if (v(i1)<0.and.u(i1)/=0) u(i1)=u(i1)+k_grid(i1)+1
       if (v(i1)<0.and.u(i1)==0) u(i1)=1
     enddo
     v=u 
   end subroutine
   !
   subroutine define_q_map(qpt_map,q_ref)
     !
     real(SP)::qpt_map(Xk%nbz,3),q_ref(3)
     !
     q_map=0
     do i1=1,Xk%nbz
       v1=matmul(k_b_m1,qpt_map(i1,:)-q_ref)
       q_iptbz(i1,:)=nint(v1)
       call k_grid_shift(q_iptbz(i1,:))
       if (q_map(q_iptbz(i1,1),q_iptbz(i1,2),q_iptbz(i1,3))/=0) then
         call warning('[RL indx] 2 equivalent points in the rlu grid found')
         q_map=0
         return
       endif
       q_map(q_iptbz(i1,1),q_iptbz(i1,2),q_iptbz(i1,3))=i1
     enddo
     !
     ! Now I fill the holes in the map shifting the whole grid
     !
     do i1=1,Xk%nbz
       do i2=-2,2
         do i3=-2,2
           do i4=-2,2
             v1=matmul(k_b_m1,qpt_map(i1,:)-q_ref+real((/i2,i3,i4/)))
             iv1=nint(v1)
             call k_grid_shift(iv1)
             if (q_map(iv1(1),iv1(2),iv1(3))==0) q_map(iv1(1),iv1(2),iv1(3))=i1
           enddo
         enddo
       enddo
     enddo
   end subroutine
   !
   subroutine q_shadows(force_gamma_only)
     use vec_operate,    ONLY:iku_v_norm
     logical                ::force_gamma_only
     !
     ! Gamma only, deallocate and reallocate 
     ! using Gamma point only definition
     !
     if (force_gamma_only) then
       if (allocated(k_pt))    deallocate(k_pt)
       if (allocated(q_pt))    deallocate(q_pt)
       if (allocated(q_norm))  deallocate(q_norm)
       if (allocated(q_sstar)) deallocate(q_sstar)
       if (associated(q%pt)) then
         deallocate(q%pt)      
         nullify(q%pt)
       endif
       call mem_est("k_pt q_pt q_norm q_sstar q-pt")
       allocate(q%pt(1,3),q_pt(1,3),k_pt(k%nibz,3),q_norm(1),q_sstar(1,2)) 
       q%pt=0.
       q_pt=0.
       k_pt=k%pt
       q_norm=q0_def_norm
       nqbz=1
       nqibz=1
       q%nibz=1
       q%nbz=1
       q_sstar=1
       return
     endif
     !
     ! q_pt , q_norm & k_pt
     !
     if (.not.allocated(q_pt)) then
       allocate(q_pt(q%nibz,3))
       q_pt=q%pt
       call mem_est("q_pt",(/q%nibz*3/),(/SP/))
     endif
     if (.not.allocated(k_pt)) then
       allocate(k_pt(k%nibz,3))
       k_pt=k%pt
       call mem_est("q_pt",(/k%nibz*3/),(/SP/))
     endif
     if (.not.allocated(q_norm)) then
       allocate(q_norm(q%nibz))
       do i1=1,q%nibz
         q_norm(i1)=iku_v_norm(q_pt(i1,:))
       enddo
       q_norm(1)=q0_def_norm
       call mem_est("q_norm",(/q%nibz/),(/SP/))
     endif
     !
     ! sstar
     !
     if (associated(q%sstar).and..not.allocated(q_sstar)) then
       allocate(q_sstar(q%nbz,2))
       q_sstar=q%sstar
       call mem_est("q_sstar",(/q%nbz*2/),(/IP/))
     endif
   end subroutine
   !
end subroutine
