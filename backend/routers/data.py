"""Data management endpoints — student registry demo."""
from __future__ import annotations
import logging
import uuid
from typing import Optional
from datetime import datetime

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider

from config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/data", tags=["data"])

# Pydantic models for request/response
class StudentCreate(BaseModel):
    first_name: str
    last_name: str
    email: str
    student_id: str

class StudentResponse(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: str
    student_id: str
    created_at: str

class StudentList(BaseModel):
    students: list[StudentResponse]
    total: int

# Cassandra session (lazy initialized)
_cluster: Optional[Cluster] = None
_session = None

def _get_session():
    """Get or create Cassandra session."""
    global _cluster, _session
    if _session is not None:
        return _session
    
    try:
        contact_points = [settings.cassandra_contact_point]
        # Try to connect to any available node
        auth_provider = PlainTextAuthProvider(username="cassandra", password="cassandra")
        _cluster = Cluster(contact_points, auth_provider=auth_provider)
        _session = _cluster.connect()
        
        # Initialize keyspace and table
        _initialize_schema()
        
        return _session
    except Exception as e:
        logger.error("Failed to connect to Cassandra: %s", e)
        raise HTTPException(status_code=500, detail="Cassandra connection failed")

def _initialize_schema():
    """Create keyspace and table if they don't exist."""
    try:
        # Create keyspace
        _session.execute("""
            CREATE KEYSPACE IF NOT EXISTS demo
            WITH replication = {
                'class': 'SimpleStrategy',
                'replication_factor': 3
            }
        """)
        
        # Create table
        _session.execute("""
            CREATE TABLE IF NOT EXISTS demo.students (
                id UUID PRIMARY KEY,
                first_name TEXT,
                last_name TEXT,
                email TEXT,
                student_id TEXT,
                created_at TIMESTAMP
            )
        """)
        
        logger.info("Schema initialized: keyspace 'demo' and table 'students'")
    except Exception as e:
        logger.warning("Schema initialization issue: %s (may already exist)", e)

@router.post("/students", response_model=StudentResponse)
async def create_student(data: StudentCreate) -> StudentResponse:
    """Insert a new student record."""
    try:
        session = _get_session()
        student_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        
        session.execute("""
            INSERT INTO demo.students (id, first_name, last_name, email, student_id, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (student_id, data.first_name, data.last_name, data.email, data.student_id, now))
        
        logger.info("Student created: %s (%s %s)", student_id, data.first_name, data.last_name)
        
        return StudentResponse(
            id=student_id,
            first_name=data.first_name,
            last_name=data.last_name,
            email=data.email,
            student_id=data.student_id,
            created_at=now,
        )
    except Exception as e:
        logger.error("Failed to create student: %s", e)
        raise HTTPException(status_code=500, detail=f"Failed to create student: {str(e)}")

@router.get("/students", response_model=StudentList)
async def list_students() -> StudentList:
    """List all student records."""
    try:
        session = _get_session()
        rows = session.execute("SELECT * FROM demo.students")
        
        students = [
            StudentResponse(
                id=str(row.id),
                first_name=row.first_name,
                last_name=row.last_name,
                email=row.email,
                student_id=row.student_id,
                created_at=row.created_at.isoformat() if row.created_at else "",
            )
            for row in rows
        ]
        
        return StudentList(students=students, total=len(students))
    except Exception as e:
        logger.error("Failed to list students: %s", e)
        raise HTTPException(status_code=500, detail=f"Failed to list students: {str(e)}")

@router.delete("/students/{student_id}")
async def delete_student(student_id: str) -> dict:
    """Delete a student record by ID."""
    try:
        session = _get_session()
        session.execute(
            "DELETE FROM demo.students WHERE id = %s",
            (student_id,)
        )
        
        logger.info("Student deleted: %s", student_id)
        
        return {"status": "deleted", "id": student_id}
    except Exception as e:
        logger.error("Failed to delete student: %s", e)
        raise HTTPException(status_code=500, detail=f"Failed to delete student: {str(e)}")

@router.post("/students/init")
async def init_schema() -> dict:
    """Manually initialize schema (useful for testing)."""
    try:
        _initialize_schema()
        return {"status": "schema initialized"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Schema init failed: {str(e)}")
