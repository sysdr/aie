"""Create quiz tables with optimized indexes"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

def upgrade():
    # Create quizzes table
    op.create_table(
        'quizzes',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('description', sa.Text()),
        sa.Column('category', sa.String(length=100)),
        sa.Column('difficulty', sa.String(length=20)),
        sa.Column('is_active', sa.Boolean(), default=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True)),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create optimized indexes
    op.create_index('ix_quizzes_id', 'quizzes', ['id'])
    op.create_index('ix_quizzes_title', 'quizzes', ['title'])
    op.create_index('ix_quizzes_category', 'quizzes', ['category'])
    op.create_index('ix_quizzes_difficulty', 'quizzes', ['difficulty'])
    op.create_index('ix_quizzes_is_active', 'quizzes', ['is_active'])
    op.create_index('idx_quiz_category_difficulty', 'quizzes', ['category', 'difficulty'])
    op.create_index('idx_quiz_active_created', 'quizzes', ['is_active', 'created_at'])
    
    # Create questions table
    op.create_table(
        'questions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('quiz_id', sa.Integer(), nullable=False),
        sa.Column('question_text', sa.Text(), nullable=False),
        sa.Column('question_type', sa.String(length=50), default='multiple_choice'),
        sa.Column('points', sa.Integer(), default=1),
        sa.Column('order_index', sa.Integer(), default=0),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['quiz_id'], ['quizzes.id'])
    )
    
    op.create_index('ix_questions_id', 'questions', ['id'])
    op.create_index('ix_questions_quiz_id', 'questions', ['quiz_id'])
    
    # Create answers table
    op.create_table(
        'answers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('question_id', sa.Integer(), nullable=False),
        sa.Column('answer_text', sa.Text(), nullable=False),
        sa.Column('is_correct', sa.Boolean(), default=False),
        sa.Column('order_index', sa.Integer(), default=0),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['question_id'], ['questions.id'])
    )
    
    op.create_index('ix_answers_id', 'answers', ['id'])
    op.create_index('ix_answers_question_id', 'answers', ['question_id'])

def downgrade():
    op.drop_table('answers')
    op.drop_table('questions')
    op.drop_table('quizzes')
