      subroutine g_k_g_r1_xi(it,ind_tau,g_c,ispin,key)
c     Calculates G(k;G;r') where k=1,npnt+par; G=1,nbasmpw; r'=1,nr_full -
c     key = 0 - to use QP Green's function
c     key = 1 - to use regular Green's function
      use atom_mod
      use manager_mod
      use parallel_mod
      use solid_mod
      use units_mod
      implicit none
      integer, intent(in) :: ind_tau,it,ispin,key
      complex*16, intent(out) :: g_c(nbasmpw,ndim3_k(me3_k+1),nr_full,
     &  nrel)
      integer :: k,nbnd,ind_k,nbas,irl,ibas0,i,i0,ind,i_tau,j,ib,jb
      double precision :: v(3),fc,pi2,tu,de,g_diag,green0
      complex*16 :: cc
      double precision, allocatable :: gx_tau(:)
      complex*16, allocatable :: tmp(:,:),tmp1(:,:),tmp0(:,:),
     &  tmp2(:,:)
      allocate(tmp0(nbndf,nbasmpw),tmp2(nbndf,nbndf))
      allocate(tmp1(nr_full,nbasmpw))
      allocate(tmp(nbasmpw,nbasmpw))
      pi2=pi+pi
      allocate(gx_tau(nbndf))
c     ---------------------------------------------------------------------
      do ind_k=1,ndim3_k(me3_k+1)
        k=n3_mpi_k(me3_k+1)+ind_k
        nbnd=n_bnd(k,ispin)
        if(ubi=='dft'.or.ubi=='dif'.or.ubi==' hf') then
          i_tau=me3_tau*ndim3_tau+ind_tau-1
          if(it==2) i_tau=n_tau-i_tau
          tu=tau_mesh(i_tau)
          call g_x_tau(ispin,k,gx_tau,tu,nbnd,chem_pot)
          do j=1,nbask(k)
            do ib=1,nbnd
              tmp0(ib,j)=gx_tau(ib)*conjg(ev_bnd(j,ib,ind_k,ispin))
            enddo
          enddo
        else
          if(key==0) then
            i_tau=me3_tau*ndim3_tau+ind_tau-1
            if(it==2) i_tau=n_tau-i_tau
            tmp2=(0.d0,0.d0)
     	      do i=1,nbnd
            de=e_qp(i,k,ispin)-chem_pot_qp
            g_diag=green0(de,tau_mesh(i_tau))
            do jb=1,nbnd
              do ib=1,nbnd
                tmp2(ib,jb)=tmp2(ib,jb)+q_qp(ib,i,ind_k,ispin)*g_diag
     &            *conjg(q_qp(jb,i,ind_k,ispin))
              enddo
            enddo
          enddo
        else if(key==1) then
          call ferm_unpack_tau(tmp2,
     &      g_full(1,1,1,ind_tau,ind_k,ispin),
     &      nbnd,nbndf,nbndf,it)
        endif
        call zgemm('n','c',nbnd,nbask(k),nbnd,(1.d0,0.d0),tmp2,
     &    nbndf,ev_bnd(1,1,ind_k,ispin),nbasmpw,(0.d0,0.d0),
     &    tmp0,nbndf)
      endif
      call zgemm('n','n',nbask(k),nbask(k),nbnd,(1.d0,0.d0),
     &  ev_bnd(1,1,ind_k,ispin),nbasmpw,tmp0,nbndf,
     &  (0.d0,0.d0),tmp,nbasmpw)
      nbas=nbask(k)/nrel
      do irl=1,nrel
        ibas0=(irl-1)*nbas
c     ----- Fill in the first zone for second index -----------------------
        tmp1=(0.d0,0.d0)
        do i=1,nbas
          i0=indgb(i,k)
          call zone1_number(gbs(:,i0),rbas,nrdiv,ind)
          tmp1(ind,1:nbask(k))=tmp(1:nbask(k),ibas0+i)
        enddo
        call fft3(nrdiv(1),nrdiv(2),nrdiv(3),nbask(k),tmp1,-1)
c     ----- Multiplication with the phase factor ------------------
        do i=1,nr_full
          v(:)=r_pnt(1,i)*r0b0(:,1)+r_pnt(2,i)*r0b0(:,2)
     &      +r_pnt(3,i)*r0b0(:,3)
          fc=-pi2*dot_product(pnt(:,k),v)
          cc=exp(dcmplx(0.d0,fc))/amega
          g_c(1:nbask(k),ind_k,i,irl)=tmp1(i,1:nbask(k))*cc
        enddo
      enddo                     !! over irl
      enddo                     !! over ind_k
      deallocate(tmp0,tmp2,tmp,tmp1,gx_tau)
      end
