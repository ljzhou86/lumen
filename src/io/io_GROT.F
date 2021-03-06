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
integer function io_GROT(io_db)
 !
 use pars,           ONLY:SP,IP
 use it_m,           ONLY:initactivate
 use memory_m,       ONLY:mem_est
 use D_lattice,      ONLY:nsym,inv_index
 use R_lattice,      ONLY:n_g_shells,ng_closed,ng_in_shell,E_of_shell,g_rot,&
&                         minus_G
 use IO_m,           ONLY:io_connect,io_disconnect,io_elemental,read_is_on,&
&                         io_status,io_bulk,io_header,io_sec
 implicit none
 integer :: io_db,nsym_db
 !
 io_GROT=io_connect(desc='gops',type=1,ID=io_db)
 if (io_GROT/=0) goto 1
 !
 io_GROT=io_header(io_db,IMPOSE_SN=.true.)
 if (io_GROT/=0) goto 1
 !
 if (any((/io_sec(io_db,:)==1/))) then
   call io_elemental(io_db,VAR="PARS",VAR_SZ=3,MENU=0)
   call io_elemental(io_db,I0=nsym,DB_I0=nsym_db)
   call io_elemental(io_db,I0=ng_closed, CHECK=.true.,OP=(/"<="/))
   call io_elemental(io_db,I0=n_g_shells,CHECK=.true.,OP=(/"<="/))
   call io_elemental(io_db,VAR="",VAR_SZ=0,MENU=0)
   io_GROT=io_status(io_db)
   if (io_GROT/=0) goto 1
 endif
 !
 if (.not.any((/io_sec(io_db,:)==2/))) goto 1
 !
 if (read_is_on(io_db)) then
   allocate(ng_in_shell(n_g_shells),E_of_shell(n_g_shells))
   allocate(g_rot(nsym_db,ng_closed),minus_G(ng_closed))
   call mem_est("RL_Gshells RL_Eshells",&
&               (/n_g_shells+nsym*ng_closed,n_g_shells/),(/IP,SP/))
 endif
 !
 call io_bulk(io_db,VAR="SHELLS",VAR_SZ=(/2*n_g_shells/))
 call io_bulk(io_db,I1=ng_in_shell(:n_g_shells))
 call io_bulk(io_db,R1=E_of_shell(:n_g_shells))
 !
 call io_bulk(io_db,VAR="GROT",VAR_SZ=(/nsym_db,ng_closed/))
 call io_bulk(io_db,I2=g_rot(:,:ng_closed))
 !
 if (inv_index<0) then
   call io_bulk(io_db,VAR="minusG",VAR_SZ=(/ng_closed/))
   call io_bulk(io_db,I1=minus_G(:ng_closed))
 endif
 !
 call initactivate(1,'Gmode')
 !
1 call io_disconnect(ID=io_db)
 !
end function
