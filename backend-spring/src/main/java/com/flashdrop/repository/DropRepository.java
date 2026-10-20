package com.flashdrop.repository;

import com.flashdrop.model.Drop;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface DropRepository extends JpaRepository<Drop, Long> {
}
